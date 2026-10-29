extends Node3D

# Root of every level. Resets the GameManager before the gems register themselves
# (a parent's _enter_tree runs before its children's _ready).

func _enter_tree():
	GameManager.begin_level($SpawnPosition.position)

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
