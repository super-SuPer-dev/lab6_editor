extends Node3D

# Spikes hide under the floor, shake as a warning, then pop up.

@export var down_time := 1.8
@export var warn_time := 0.5
@export var up_time := 1.2
@export_range(0.0, 1.0) var phase := 0.0
@export var hidden_depth := 1.35

@onready var spikes: Node3D = $Spikes
@onready var hazard = $Spikes/Hazard

var _time := 0.0

func _ready():
	_time = phase * (down_time + warn_time + up_time)

func _physics_process(delta):
	_time = fmod(_time + delta, down_time + warn_time + up_time)
	var y := -hidden_depth
	var shake := 0.0
	if _time < down_time:
		y = -hidden_depth
	elif _time < down_time + warn_time:
		y = -hidden_depth + 0.35
		shake = sin(_time * 80.0) * 0.04
	else:
		var t := _time - down_time - warn_time
		y = lerp(-hidden_depth + 0.35, 0.0, clamp(t / 0.08, 0.0, 1.0))
		if t > up_time - 0.25:
			y = lerp(0.0, -hidden_depth, (t - (up_time - 0.25)) / 0.25)
	spikes.position = Vector3(shake, y, 0)
	hazard.active = y > -0.7
