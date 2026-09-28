extends CharacterBody3D
## Player built from the Blender character + Mixamo bone map + OpenAnimationLibraries.

signal animation_changed(anim_name: String)

const WALK_SPEED := 2.2
const RUN_SPEED := 5.0
const JUMP_VELOCITY := 4.5
const TURN_SPEED := 10.0

const LIBRARIES := {
	"melee": preload("res://assets/animations/MeleeLib.res"),
	"shooter": preload("res://assets/animations/ShooterLib.res"),
}

const ANIM_IDLE := "shooter/idle"
const ANIM_WALK := "shooter/walk"
const ANIM_RUN := "shooter/run_067"
const ANIM_JUMP := "shooter/jump"
const ANIM_FALL := "shooter/fall"

## Quick actions on number keys 1-9.
const QUICK_ACTIONS := [
	"melee/Slash1", "melee/Heavy1", "melee/Stab1", "shooter/punch1", "shooter/kick1",
	"melee/Roll", "melee/UsePotion", "shooter/search-shrug", "melee/Die1",
]

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var action_playing := false
var demo_loop := ""  # looping animation chosen from the menu, overrides locomotion while standing still

@onready var model: Node3D = $Model
@onready var anim: AnimationPlayer = $Model/AnimationPlayer
@onready var camera_pivot: Node3D = $CameraPivot


func _ready() -> void:
	for lib_name in LIBRARIES:
		anim.add_animation_library(lib_name, _clean_library(LIBRARIES[lib_name]))
	anim.animation_finished.connect(_on_animation_finished)
	_play(ANIM_IDLE)


## Removes tracks for bones our skeleton doesn't have (Weapon, Root),
## so the mixer doesn't complain about unresolved tracks.
func _clean_library(src: AnimationLibrary) -> AnimationLibrary:
	var skeleton: Skeleton3D = model.find_child("GeneralSkeleton", true, false)
	var lib := AnimationLibrary.new()
	for anim_name in src.get_animation_list():
		if anim_name.begins_with("root-") or anim_name.begins_with("Armature|"):
			continue
		var a: Animation = src.get_animation(anim_name).duplicate()
		for i in range(a.get_track_count() - 1, -1, -1):
			var bone := str(a.track_get_path(i).get_concatenated_subnames())
			if bone != "" and skeleton.find_bone(bone) == -1:
				a.remove_track(i)
		lib.add_animation(anim_name, a)
	return lib


func get_all_animations() -> PackedStringArray:
	var names := PackedStringArray()
	for lib_name in LIBRARIES:
		for anim_name in anim.get_animation_library(lib_name).get_animation_list():
			names.append("%s/%s" % [lib_name, anim_name])
	return names


## Plays any animation from the menu. Looping ones stay until the player moves.
func play_demo(anim_name: String) -> void:
	var a := anim.get_animation(anim_name)
	if a.loop_mode == Animation.LOOP_NONE:
		demo_loop = ""
		action_playing = true
	else:
		demo_loop = anim_name
		action_playing = false
	_play(anim_name)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var idx: int = event.keycode - KEY_1
		if idx >= 0 and idx < QUICK_ACTIONS.size():
			play_demo(QUICK_ACTIONS[idx])


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Move relative to where the camera looks.
	var dir := (Basis(Vector3.UP, camera_pivot.global_rotation.y) * Vector3(input.x, 0, input.y)).normalized()
	var running := Input.is_action_pressed("run")
	var speed := RUN_SPEED if running else WALK_SPEED

	if action_playing and is_on_floor():
		dir = Vector3.ZERO  # stand still during attacks etc.

	if dir != Vector3.ZERO:
		demo_loop = ""
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		var target := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target, TURN_SPEED * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * 4 * delta)
		velocity.z = move_toward(velocity.z, 0, speed * 4 * delta)

	if Input.is_action_just_pressed("jump") and is_on_floor() and not action_playing:
		velocity.y = JUMP_VELOCITY
		demo_loop = ""
		_play(ANIM_JUMP)

	move_and_slide()
	_update_locomotion(dir != Vector3.ZERO, running)


func _update_locomotion(moving: bool, running: bool) -> void:
	if action_playing:
		return
	if not is_on_floor():
		if anim.current_animation != ANIM_JUMP:
			_play(ANIM_FALL)
	elif moving:
		_play(ANIM_RUN if running else ANIM_WALK)
	elif demo_loop != "":
		_play(demo_loop)
	else:
		_play(ANIM_IDLE)


func _play(anim_name: String) -> void:
	if anim.current_animation == anim_name and anim.is_playing():
		return
	anim.play(anim_name, 0.2)
	animation_changed.emit(anim_name)


func _on_animation_finished(anim_name: StringName) -> void:
	if not action_playing:
		return
	# Hold the death pose for a moment before getting back up.
	if str(anim_name) == "melee/Die1":
		await get_tree().create_timer(1.0).timeout
	action_playing = false
	_play(ANIM_IDLE)
