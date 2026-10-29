extends Area3D

# Touch the flag to save a respawn point.

@onready var flag: Node3D = $Flag
@onready var light: OmniLight3D = $Light
@onready var burst: CPUParticles3D = $Burst

var activated := false

func _ready():
	body_entered.connect(_on_body_entered)
	flag.scale = Vector3.ONE * 0.55
	light.visible = false

func _on_body_entered(body):
	if activated or not body.is_in_group("Player"):
		return
	activated = true
	GameManager.set_checkpoint(global_position + Vector3.UP * 0.5)
	AudioManager.checkpoint_sfx.play()
	light.visible = true
	burst.restart()
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(flag, "scale", Vector3.ONE * 1.1, 0.4)
