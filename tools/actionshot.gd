extends SceneTree
# Lab 6 check: loads a level, presses the new action keys and captures the screen mid-move.
# usage: --script actionshot.gd -- <level scene> <outprefix> x,y,z,yaw
func _initialize():
	var args := OS.get_cmdline_user_args()
	var scene: Node = load(args[0]).instantiate()
	root.add_child(scene)
	current_scene = scene
	var p: CharacterBody3D = scene.get_node("Player")
	var gimbal: Node3D = p.get_node("Gimbal")
	var v := Array(args[2].split(",")).map(func(s): return float(s))
	for k in 330: await process_frame
	p.global_position = Vector3(v[0], v[1], v[2])
	gimbal.rotation_degrees = Vector3(-14, v[3] + 35, 0)
	gimbal.set("auto_rotate", false)
	gimbal.get_node("CameraControlTimer").stop()
	gimbal.position = p.position
	p.get_node("Model").rotation.y = deg_to_rad(v[3] + 180.0)
	for k in 40: await process_frame
	var steps := [["idle", "", 5], ["run", "move_forward", 24], ["attack", "attack", 20], ["combo", "attack", 22],
		["kick", "kick", 16], ["dodge", "dodge", 14], ["jump", "jump", 14]]
	for s in steps:
		if s[1] != "":
			Input.action_press(s[1])
			await process_frame
			if s[1] != "move_forward":
				Input.action_release(s[1])
		for k in s[2]: await process_frame
		var anim: AnimationPlayer = p.get_node("AnimationPlayer")
		print(s[0], " -> ", anim.current_animation, " hearts=", root.get_node("GameManager").hearts)
		root.get_texture().get_image().save_png("%s_%s.png" % [args[1], s[0]])
		Input.action_release("move_forward")
		for k in 30: await process_frame
	quit()
