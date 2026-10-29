extends Area3D

# Falling into the sand sea (Level 1) or lava (Level 2) costs a heart
# and sends the player back to the last checkpoint.

# ---------- SIGNALS ---------- #

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	# Checks if player is colliding with the dead zone & reset player position if true
	if body.is_in_group("Player"):
		body.fall_out()
