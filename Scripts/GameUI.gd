extends Control

# HUD: gems collected, hearts, level banner and short messages.

# ---------- VARIABLES ---------- #

@export var level_title := "ด่าน 1"
@export var level_subtitle := ""

@onready var coinsLabel = $TopBar/CoinsLabel
@onready var hearts = $TopBar/Hearts
@onready var banner = $Banner
@onready var banner_title = $Banner/Title
@onready var banner_sub = $Banner/Subtitle
@onready var toast = $Toast
@onready var time_label = $TimeLabel

var _toast_tween: Tween

# ---------- FUNCTIONS ---------- #

func _ready():
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.hearts_changed.connect(_on_hearts_changed)
	GameManager.message.connect(show_message)
	_on_score_changed(GameManager.score, GameManager.total)
	_on_hearts_changed(GameManager.hearts)
	toast.modulate.a = 0.0
	banner_title.text = level_title
	banner_sub.text = level_subtitle
	banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(banner, "modulate:a", 1.0, 0.6)
	tw.tween_interval(2.6)
	tw.tween_property(banner, "modulate:a", 0.0, 0.8)

func _process(_delta):
	time_label.text = GameManager.format_time(GameManager.play_time)

func _on_score_changed(score, total):
	coinsLabel.text = "%d / %d" % [score, total] # Set the coin label text to the score variable
	var tw := create_tween()
	coinsLabel.pivot_offset = coinsLabel.size / 2
	tw.tween_property(coinsLabel, "scale", Vector2.ONE * 1.25, 0.08)
	tw.tween_property(coinsLabel, "scale", Vector2.ONE, 0.15)

func _on_hearts_changed(value):
	hearts.hearts = value

func show_message(text: String):
	toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(toast, "modulate:a", 0.0, 0.5)
