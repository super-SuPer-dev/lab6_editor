@tool
extends Control

# Draws low-poly style hearts so no image or emoji font is needed.

@export var max_hearts := 3:
	set(v):
		max_hearts = v
		queue_redraw()
@export var hearts := 3:
	set(v):
		hearts = v
		queue_redraw()
@export var heart_size := 34.0
@export var full_color := Color(0.93, 0.22, 0.3)
@export var empty_color := Color(0.25, 0.18, 0.18, 0.55)

func _draw():
	for i in max_hearts:
		var c := full_color if i < hearts else empty_color
		_draw_heart(Vector2(i * (heart_size + 8) + heart_size / 2, heart_size / 2), heart_size, c)

func _draw_heart(center: Vector2, s: float, color: Color):
	var r := s * 0.27
	var outline := Color(0.15, 0.07, 0.05, 0.9)
	var pts := PackedVector2Array([
		center + Vector2(-s * 0.5, -s * 0.08),
		center + Vector2(0, s * 0.48),
		center + Vector2(s * 0.5, -s * 0.08),
	])
	# outline
	draw_circle(center + Vector2(-r, -s * 0.12), r + 3, outline)
	draw_circle(center + Vector2(r, -s * 0.12), r + 3, outline)
	draw_colored_polygon(PackedVector2Array([pts[0] + Vector2(-3, 0), pts[1] + Vector2(0, 4), pts[2] + Vector2(3, 0)]), outline)
	draw_circle(center + Vector2(-r, -s * 0.12), r, color)
	draw_circle(center + Vector2(r, -s * 0.12), r, color)
	draw_colored_polygon(pts, color)
	draw_circle(center + Vector2(-r * 1.2, -s * 0.22), r * 0.3, Color(1, 1, 1, 0.45))

func _get_minimum_size() -> Vector2:
	return Vector2(max_hearts * (heart_size + 8), heart_size)
