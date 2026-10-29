extends Node3D

# Gently sways the camera around the character on the title / win screens.

@export var sway_degrees := 7.0
@export var sway_speed := 0.35
@export var animation_name := "Idle"

var _time := 0.0

func _ready():
	var anim: AnimationPlayer = get_node_or_null("../Player/AnimationPlayer")
	if anim:
		CharacterAnims.setup(anim, anim.get_node(anim.root_node))
		anim.play(animation_name)

func _process(delta):
	_time += delta
	rotation_degrees.y = sin(_time * sway_speed) * sway_degrees
