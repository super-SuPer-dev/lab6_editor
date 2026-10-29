extends Node3D

# Swings the spiky ball that hangs from the Pivot child.

@export var max_angle := 65.0
@export var period := 2.6
@export_range(0.0, 1.0) var phase := 0.0
@export var axis := Vector3.RIGHT

@onready var pivot: Node3D = $Pivot

var _time := 0.0

func _ready():
	_time = phase * period

func _physics_process(delta):
	_time += delta
	var angle := deg_to_rad(max_angle) * sin(TAU * _time / period)
	pivot.basis = Basis(axis.normalized(), angle)
