extends Node3D
## Demo scene: UI panel listing every animation from the Melee and Shooter libraries.

const STUDENT := "นาย พุฒิพงศ์ พานิชพันธุ์  673380335-3"

@onready var player: CharacterBody3D = $Player

var list: ItemList
var filter: LineEdit
var now_playing: Label
var all_anims: PackedStringArray


func _ready() -> void:
	all_anims = player.get_all_animations()
	_build_ui()
	player.animation_changed.connect(func(n: String): now_playing.text = "ท่าปัจจุบัน: " + n)
	_refresh_list("")
	if OS.get_cmdline_user_args().has("--screenshot"):
		_take_screenshots()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(300, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.82)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var title := Label.new()
	title.text = "Lab 6 : สร้างตัวละคร 3D"
	title.add_theme_font_size_override("font_size", 22)
	box.add_child(title)

	var who := Label.new()
	who.text = STUDENT
	who.add_theme_font_size_override("font_size", 14)
	who.add_theme_color_override("font_color", Color(0.75, 0.82, 0.95))
	box.add_child(who)

	var help := Label.new()
	help.text = "WASD / ลูกศร = เดิน   Shift = วิ่ง   Space = กระโดด\nลากเมาส์ / Q E = หมุนกล้อง   ล้อเมาส์ = ซูม\n1-9 = ท่าโจมตี/ท่าพิเศษ   คลิกรายการ = เล่นท่านั้น"
	help.add_theme_font_size_override("font_size", 13)
	box.add_child(help)

	now_playing = Label.new()
	now_playing.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	box.add_child(now_playing)

	filter = LineEdit.new()
	filter.placeholder_text = "ค้นหาท่า เช่น slash, idle, crouch"
	filter.text_changed.connect(_refresh_list)
	filter.text_submitted.connect(func(_t): filter.release_focus())
	box.add_child(filter)

	list = ItemList.new()
	list.custom_minimum_size = Vector2(0, 360)
	list.focus_mode = Control.FOCUS_NONE
	list.item_clicked.connect(func(i, _pos, _btn): player.play_demo(list.get_item_text(i)))
	box.add_child(list)


func _refresh_list(query: String) -> void:
	list.clear()
	for n in all_anims:
		if query == "" or n.to_lower().contains(query.to_lower()):
			list.add_item(n)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		filter.release_focus()


## Saves a few screenshots for the lab report: godot -- --screenshot
func _take_screenshots() -> void:
	var shots := {"idle": "shooter/idle", "slash": "melee/Slash1", "kick": "shooter/kick1", "crouch": "shooter/crouch-idle"}
	for key in shots:
		player.play_demo(shots[key])
		await get_tree().create_timer(0.45).timeout
		var img := get_viewport().get_texture().get_image()
		img.save_png("user://shot_%s.png" % key)
	print("screenshots saved to ", ProjectSettings.globalize_path("user://"))
	get_tree().quit()
