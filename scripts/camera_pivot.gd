extends Node3D
## Orbit camera: drag with the mouse (left or right button) to rotate, wheel to zoom.
## Q / E also rotate for keyboard-only play.

const MOUSE_SENSITIVITY := 0.005
const KEY_TURN_SPEED := 2.0

@onready var spring_arm: SpringArm3D = $SpringArm3D

var dragging := false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			spring_arm.spring_length = max(1.5, spring_arm.spring_length - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			spring_arm.spring_length = min(8.0, spring_arm.spring_length + 0.3)
	elif event is InputEventMouseMotion and dragging:
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY
		rotation.x = clamp(rotation.x - event.relative.y * MOUSE_SENSITIVITY, -1.2, 0.3)


func _process(delta: float) -> void:
	var turn := Input.get_axis("cam_right", "cam_left")
	rotation.y += turn * KEY_TURN_SPEED * delta
