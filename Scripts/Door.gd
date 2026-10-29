extends Area3D

# Exit door. Locked until every gem in the level is collected.

@onready var door_pivot: Node3D = $DoorPivot
@onready var blocker: CollisionShape3D = $Blocker/CollisionShape3D
@onready var portal: MeshInstance3D = $Portal
@onready var light: OmniLight3D = $Light
@onready var sign_label: Label3D = $Sign

var is_open := false
var used := false

func _ready():
	body_entered.connect(_on_body_entered)
	GameManager.all_collected.connect(open)
	GameManager.score_changed.connect(_update_sign)
	portal.visible = false
	light.light_color = Color(1.0, 0.35, 0.25)
	_update_sign.call_deferred(GameManager.score, GameManager.total)

func _process(delta):
	if is_open:
		portal.rotate_object_local(Vector3.FORWARD, delta * 1.5)

func _update_sign(score, total):
	if not is_open:
		sign_label.text = "ประตูล็อก  %d / %d" % [score, total]

func open():
	if is_open:
		return
	is_open = true
	AudioManager.door_sfx.play()
	blocker.set_deferred("disabled", true)
	sign_label.text = "เข้าประตูได้เลย!"
	sign_label.modulate = Color(0.6, 1.0, 0.6)
	light.light_color = Color(0.45, 1.0, 0.6)
	portal.visible = true
	portal.scale = Vector3.ONE * 0.01
	var tw := create_tween().set_parallel()
	tw.tween_property(door_pivot, "rotation_degrees:y", -105.0, 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(portal, "scale", Vector3.ONE, 0.8).set_delay(0.4)
	tw.tween_property(light, "light_energy", 3.0, 0.8)

func _on_body_entered(body):
	if not body.is_in_group("Player") or used:
		return
	if is_open:
		used = true
		body.celebrate()
		AudioManager.portal_sfx.play()
		GameManager.message.emit("ผ่านด่าน!")
		await get_tree().create_timer(1.6).timeout
		GameManager.next_level()
	else:
		AudioManager.locked_sfx.play()
		GameManager.message.emit("เก็บคริสตัลให้ครบก่อน! (%d / %d)" % [GameManager.score, GameManager.total])
