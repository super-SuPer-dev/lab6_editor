extends Area3D

# Anything with this script hurts the player on touch (spikes, spiky balls, spinning logs).

@export var active := true

func _ready():
	body_entered.connect(_try_hurt)

func _physics_process(_delta):
	# Keep hurting while the player stays inside (after the invincibility blink ends)
	if active:
		for body in get_overlapping_bodies():
			_try_hurt(body)

func _try_hurt(body):
	if active and body.is_in_group("Player"):
		body.take_damage(global_position)
