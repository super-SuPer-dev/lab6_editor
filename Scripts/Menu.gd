extends Control

# Title screen and win screen buttons.

@export var is_win_screen := false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	for b in $Panel/VBox.get_children():
		if b is Button:
			b.pressed.connect(AudioManager.click_sfx.play)
	$Panel/VBox/StartButton.pressed.connect(GameManager.start_game)
	if has_node("Panel/VBox/DemoButton"):
		$Panel/VBox/DemoButton.pressed.connect(GameManager.goto_demo)
	if has_node("Panel/VBox/TitleButton"):
		$Panel/VBox/TitleButton.pressed.connect(GameManager.goto_title)
	if is_win_screen:
		AudioManager.win_sfx.play()
		$Panel/VBox/TimeLabel.text = "เวลาที่ใช้: " + GameManager.format_time(GameManager.play_time)
	$Panel/VBox/StartButton.grab_focus()
