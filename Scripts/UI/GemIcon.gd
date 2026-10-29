@tool
extends Control

# Small faceted gem drawn for the HUD counter.

@export var color := Color(0.3, 0.75, 1.0)

func _draw():
	var s := size
	var c := Vector2(s.x / 2, s.y / 2)
	var top := Vector2(c.x, 2)
	var bottom := Vector2(c.x, s.y - 2)
	var left := Vector2(2, s.y * 0.38)
	var right := Vector2(s.x - 2, s.y * 0.38)
	var outline := Color(0.12, 0.08, 0.06)
	draw_colored_polygon(PackedVector2Array([top + Vector2(0, -3), right + Vector2(3, 0), bottom + Vector2(0, 4), left + Vector2(-3, 0)]), outline)
	draw_colored_polygon(PackedVector2Array([top, right, bottom, left]), color)
	draw_colored_polygon(PackedVector2Array([top, c + Vector2(0, -s.y * 0.12), left]), color.lightened(0.45))
	draw_colored_polygon(PackedVector2Array([right, c + Vector2(0, -s.y * 0.12), bottom]), color.darkened(0.3))
