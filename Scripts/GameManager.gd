extends Node

# ---------- SIGNALS ---------- #

signal score_changed(score: int, total: int)
signal hearts_changed(hearts: int)
signal all_collected
signal message(text: String)

# ---------- VARIABLES ---------- #

const LEVELS := [
	"res://Scenes/Levels/Level1.tscn",
	"res://Scenes/Levels/Level2.tscn",
]
const TITLE_SCENE := "res://Scenes/UI/Title.tscn"
const WIN_SCENE := "res://Scenes/UI/Win.tscn"
const DEMO_SCENE := "res://Scenes/Demo/CharacterDemo.tscn"
const MAX_HEARTS := 3

var score := 0
var total := 0
var hearts := MAX_HEARTS
var level_index := 0
var checkpoint := Vector3.ZERO
var play_time := 0.0
var timer_running := false
var changing_scene := false

var _fade_rect: ColorRect
var _loading_label: Label

# ---------- FUNCTIONS ---------- #

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_add_extra_keys()

func _process(delta):
	show_mouse_cursor()
	if timer_running:
		play_time += delta

# Making Cursor visible using "mouse_visible" key which is assigned in Project Settings > Input Map
func show_mouse_cursor():
	if Input.is_action_just_pressed("mouse_visible"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event):
	# Click inside the game to lock the mouse again (needed on the web)
	if event is InputEventMouseButton and event.pressed and is_in_level():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

# Arrow keys work as well as WASD; logical keycodes too, for browsers that send no physical key code
func _add_extra_keys():
	var extra := {
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"move_forward": [KEY_UP, KEY_W], "move_back": [KEY_DOWN, KEY_S], "jump": [KEY_SPACE],
		"attack": [KEY_F, KEY_J], "kick": [KEY_K], "dodge": [KEY_SHIFT, KEY_C],
		# Character demo scene: run and turn the camera
		"run": [KEY_SHIFT], "cam_left": [KEY_Q], "cam_right": [KEY_E],
	}
	for action in extra:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for key in extra[action]:
			var ev := InputEventKey.new()
			ev.keycode = key
			InputMap.action_add_event(action, ev)

func is_in_level() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.scene_file_path in LEVELS

# Called by Level.gd before the gems in the level register themselves
func begin_level(spawn: Vector3):
	score = 0
	total = 0
	hearts = MAX_HEARTS
	checkpoint = spawn
	timer_running = true

func register_collectible():
	total += 1
	score_changed.emit(score, total)

func add_score():
	score += 1
	score_changed.emit(score, total)
	if score >= total:
		all_collected.emit()
		message.emit("ประตูเปิดแล้ว! รีบไปที่ประตูเลย")

func has_all() -> bool:
	return total > 0 and score >= total

func set_checkpoint(pos: Vector3):
	checkpoint = pos
	message.emit("บันทึกจุดเกิดใหม่แล้ว")

# Returns true when the player still has hearts left
func lose_heart() -> bool:
	hearts = max(hearts - 1, 0)
	hearts_changed.emit(hearts)
	return hearts > 0

func start_game():
	level_index = 0
	play_time = 0.0
	goto_scene(LEVELS[0])

func restart_level():
	goto_scene(LEVELS[level_index])

func next_level():
	level_index += 1
	if level_index < LEVELS.size():
		goto_scene(LEVELS[level_index])
	else:
		timer_running = false
		goto_scene(WIN_SCENE)

func goto_title():
	timer_running = false
	goto_scene(TITLE_SCENE)

# Lab 6: free-roam scene that lists every Melee / Shooter clip
func goto_demo():
	timer_running = false
	goto_scene(DEMO_SCENE)

# Fade out, swap scene, fade back in
func goto_scene(path: String):
	if changing_scene:
		return
	changing_scene = true
	var fade := _get_fade()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.4)
	await tween.finished
	_loading_label.visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	changing_scene = false
	_loading_label.visible = false
	tween = create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.5)

func _get_fade() -> ColorRect:
	if _fade_rect == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		_fade_rect = ColorRect.new()
		_fade_rect.color = Color(0.1, 0.06, 0.04, 0.0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer.add_child(_fade_rect)
		_loading_label = Label.new()
		_loading_label.text = "กำลังโหลด..."
		_loading_label.add_theme_font_size_override("font_size", 40)
		_loading_label.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
		_loading_label.set_anchors_preset(Control.PRESET_CENTER)
		_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_loading_label.offset_left = -300
		_loading_label.offset_right = 300
		_loading_label.visible = false
		layer.add_child(_loading_label)
	return _fade_rect

func format_time(t: float) -> String:
	return "%02d:%02d" % [int(t) / 60, int(t) % 60]
