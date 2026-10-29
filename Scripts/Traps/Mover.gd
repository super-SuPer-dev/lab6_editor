extends Node3D

# Moves back and forth between the start position and start + offset.
# Works for AnimatableBody3D platforms (player rides along) and for hazards.

@export var offset := Vector3(0, 0, -6)
@export var duration := 3.0
@export_range(0.0, 1.0) var phase := 0.0

var _start := Vector3.ZERO
var _time := 0.0

func _ready():
	_start = position
	_time = phase * duration

func _physics_process(delta):
	_time += delta
	var t := 0.5 - 0.5 * cos(TAU * _time / duration)
	position = _start + offset * t
