extends Node3D

# Spins a child (e.g. "Rotor" with spiked logs) or this node itself around a local axis.

@export var axis := Vector3.UP
@export var degrees_per_second := 90.0
@export var rotate_child := ""

@onready var target: Node3D = get_node(rotate_child) if rotate_child != "" else self

func _physics_process(delta):
	target.rotate_object_local(axis.normalized(), deg_to_rad(degrees_per_second) * delta)
