# ----------------------------------------------------------------------------------- #
# -------------- FEEL FREE TO USE IN ANY PROJECT, COMMERCIAL OR NON-COMMERCIAL ------ #
# ---------------------- 3D PLATFORMER CONTROLLER BY SD STUDIOS --------------------- #
# ---------------------------- ATTRIBUTION NOT REQUIRED ----------------------------- #
# ----------------------------------------------------------------------------------- #
# Lab 5: model swapped from Gobot to Cactoro (Poly Pizza), animations remapped to the
# kit's names (Idle / Run / Jump / Flip) in Assets/Animations/cactoro_anims.tres,
# plus hearts, knockback, checkpoints and a victory pose.
# Lab 6: Cactoro replaced by the student character made in Blender (Mixamo skeleton,
# retargeted with Mixamo BoneMap.tres). Its clips come from the Melee and Shooter
# libraries through CharacterAnims.gd, which also adds a slash combo, a kick and a dodge roll.

extends CharacterBody3D

const ATTACK_COMBO := ["melee/Slash1", "melee/Slash2", "melee/Stab1"]
const ATTACK_SPEED := 1.4
const COMBO_WINDOW := 0.45

# ---------- VARIABLES ---------- #

@export_category("Player Properties")
@export var move_speed : float = 7
@export var jump_force : float = 7.5
@export var follow_lerp_factor : float = 4
@export var jump_limit : int = 2
@export var knockback_force : float = 9
@export var invincible_time : float = 1.5
@export var step_interval : float = 0.32
@export var dodge_speed : float = 11
@export var dodge_cooldown : float = 0.4

@export_group("Game Juice")
@export var jumpStretchSize := Vector3(0.8, 1.2, 0.8)

# Booleans
var is_grounded = false
var can_double_jump = false
var is_flipping = false
var controls_locked = false

var invincible_timer := 0.0
var anim_lock_timer := 0.0
var knockback := Vector3.ZERO
var step_timer := 0.0
var step_index := 0

# Attacks and dodge roll
var attack_timer := 0.0
var combo_index := 0
var combo_timer := 0.0
var dodge_timer := 0.0
var dodge_cooldown_timer := 0.0
var dodge_direction := Vector3.ZERO

# Onready Variables
@onready var model = $Model
@onready var animation = $AnimationPlayer
@onready var spring_arm = %Gimbal

@onready var particle_trail = $ParticleTrail

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity") * 2

# ---------- FUNCTIONS ---------- #

func _ready():
	spring_arm.position = position
	CharacterAnims.setup(animation, model)
	animation.play("Idle")

func _process(delta):
	invincible_timer = max(invincible_timer - delta, 0.0)
	anim_lock_timer = max(anim_lock_timer - delta, 0.0)
	attack_timer = max(attack_timer - delta, 0.0)
	combo_timer = max(combo_timer - delta, 0.0)
	dodge_timer = max(dodge_timer - delta, 0.0)
	dodge_cooldown_timer = max(dodge_cooldown_timer - delta, 0.0)
	handle_actions()
	# Blink while invincible
	model.visible = invincible_timer <= 0.0 or int(invincible_timer * 12) % 2 == 0

	player_animations()
	play_footsteps(delta)
	get_input(delta)

	# Smoothly follow player's position
	spring_arm.position = lerp(spring_arm.position, position, delta * follow_lerp_factor)

	# Player Rotation
	if is_moving() and not controls_locked:
		var look_direction = Vector2(velocity.z, velocity.x)
		model.rotation.y = lerp_angle(model.rotation.y, look_direction.angle(), delta * 12)
		if spring_arm.auto_rotate:
			spring_arm.rotation.y = lerp_angle(spring_arm.rotation.y, look_direction.angle()-deg_to_rad(180), delta*0.4)
			spring_arm.rotation.x = lerp_angle(spring_arm.rotation.x, deg_to_rad(-12), delta*0.4)

	# Check if player is grounded or not
	is_grounded = true if is_on_floor() else false

	# Handle Jumping
	if is_grounded:
		can_double_jump = true

	if Input.is_action_just_pressed("jump") and not controls_locked:
		if is_on_floor():
			perform_jump()
		elif can_double_jump:
			if is_moving():
				perform_flip_jump()

	velocity.y -= gravity * delta

func perform_jump():
	AudioManager.jump_sfx.play()
	AudioManager.jump_sfx.pitch_scale = 1.12

	jumpTween()
	animation.play("Jump")
	velocity.y = jump_force

func perform_flip_jump():
	AudioManager.jump_sfx.play()
	AudioManager.jump_sfx.pitch_scale = 0.8
	can_double_jump = false
	is_flipping = true
	animation.play("Flip", -1, 1.6)
	velocity.y = jump_force
	await get_tree().create_timer(animation.get_animation("Flip").length / 1.6).timeout
	is_flipping = false
	if not is_on_floor():
		animation.play("Jump", 0.3)

func is_moving():
	return abs(velocity.z) > 0 || abs(velocity.x) > 0

func jumpTween():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "scale", jumpStretchSize, 0.1)
	tween.tween_property(self, "scale", Vector3(1,1,1), 0.1)

# Get Player Input
func get_input(delta):
	var move_direction := Vector3.ZERO
	if not controls_locked:
		move_direction.x = Input.get_axis("move_left", "move_right")
		move_direction.z = Input.get_axis("move_forward", "move_back")

	# Move The player Towards Spring Arm/Camera Rotation
	move_direction = move_direction.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	var speed := move_speed
	if dodge_timer > 0.0:
		move_direction = dodge_direction
		speed = dodge_speed
	elif attack_timer > 0.0 and is_on_floor():
		speed = move_speed * 0.15  # plant the feet while swinging
	velocity = Vector3(move_direction.x * speed, velocity.y, move_direction.z * speed)

	# Knockback from traps fades out quickly
	velocity += knockback
	knockback = knockback.lerp(Vector3.ZERO, delta * 5)

	move_and_slide()

# ---------- ATTACKS / DODGE (Lab 6) ---------- #

func handle_actions():
	if controls_locked or anim_lock_timer > 0.0 and attack_timer <= 0.0 and dodge_timer <= 0.0:
		return
	if Input.is_action_just_pressed("dodge") and is_on_floor() and dodge_timer <= 0.0 and dodge_cooldown_timer <= 0.0:
		perform_dodge()
	elif Input.is_action_just_pressed("attack") and attack_timer <= 0.0 and dodge_timer <= 0.0:
		combo_index = combo_index + 1 if combo_timer > 0.0 else 0
		perform_attack(ATTACK_COMBO[combo_index % ATTACK_COMBO.size()])
	elif Input.is_action_just_pressed("kick") and attack_timer <= 0.0 and dodge_timer <= 0.0:
		perform_attack("shooter/kick1")

func perform_attack(anim_name: String):
	AudioManager.jump_sfx.pitch_scale = 1.6
	AudioManager.jump_sfx.play()
	is_flipping = false
	animation.play(anim_name, 0.08, ATTACK_SPEED)
	attack_timer = animation.get_animation(anim_name).length / ATTACK_SPEED * 0.8
	anim_lock_timer = attack_timer
	combo_timer = attack_timer + COMBO_WINDOW

# Quick roll in the move direction (or forward); traps can't hurt you mid-roll
func perform_dodge():
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_forward", "move_back"))
	if dir == Vector3.ZERO:
		dodge_direction = model.global_transform.basis.z.normalized()
	else:
		dodge_direction = dir.rotated(Vector3.UP, spring_arm.rotation.y).normalized()
	model.rotation.y = atan2(dodge_direction.x, dodge_direction.z)
	attack_timer = 0.0
	animation.play("Dodge", 0.05, 1.3)
	dodge_timer = animation.get_animation("Dodge").length / 1.3
	anim_lock_timer = dodge_timer
	dodge_cooldown_timer = dodge_timer + dodge_cooldown
	AudioManager.jump_sfx.pitch_scale = 0.7
	AudioManager.jump_sfx.play()

# Handle Player Animations
func player_animations():
	particle_trail.emitting = false

	if anim_lock_timer > 0.0 or is_flipping or controls_locked:
		return

	if is_on_floor():
		if is_moving(): # Checks if player is moving
			animation.play("Run", 0.3)
			particle_trail.emitting = true
		else:
			animation.play("Idle", 0.3)
	elif animation.current_animation != "Jump":
		animation.play("Fall", 0.3)

# Play one step every step_interval while running on the ground
func play_footsteps(delta):
	if not is_on_floor() or not is_moving() or controls_locked:
		step_timer = 0.0
		return
	step_timer -= delta
	if step_timer <= 0.0:
		step_timer = step_interval
		# Non-positional players in AudioManager, one per foot (3D players fade/stutter on the web)
		var step = AudioManager.step_sfx[step_index % 2]
		step.pitch_scale = randf_range(0.92, 1.08)
		step.play()
		step_index += 1

# ---------- DAMAGE / RESPAWN ---------- #

# Called by traps (Hazard.gd)
func take_damage(from_position: Vector3):
	if invincible_timer > 0.0 or dodge_timer > 0.0 or controls_locked:
		return
	attack_timer = 0.0
	AudioManager.hurt_sfx.play()
	var away := global_position - from_position
	away.y = 0
	if away.length() < 0.1:
		away = -model.global_transform.basis.z
	knockback = away.normalized() * knockback_force
	velocity.y = jump_force * 0.7
	invincible_timer = invincible_time
	anim_lock_timer = 0.5
	is_flipping = false
	animation.play("Hurt", 0.1)
	if not GameManager.lose_heart():
		die()

# Called by DeadZone.gd when falling into sand / lava
func fall_out():
	if controls_locked:
		return
	AudioManager.fall_sfx.play()
	if GameManager.lose_heart():
		respawn()
	else:
		die()

func respawn():
	global_position = GameManager.checkpoint
	velocity = Vector3.ZERO
	knockback = Vector3.ZERO
	spring_arm.position = position
	invincible_timer = invincible_time

func die():
	controls_locked = true
	animation.play("Death", 0.1)
	GameManager.message.emit("หัวใจหมดแล้ว! เริ่มด่านใหม่...")
	await get_tree().create_timer(1.8).timeout
	GameManager.restart_level()

# Called by Door.gd when entering the open door
func celebrate():
	controls_locked = true
	velocity = Vector3.ZERO
	animation.play("Victory", 0.2)
