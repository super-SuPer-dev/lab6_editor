extends SceneTree
# Renders the student character in several clips (at a given point of each clip) into one image.
# Usage: godot --path . -s tools/student_poses.gd -- out.png 0.5 clip1 clip2 ...
func _initialize():
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var t := float(args[1])
	var names := args.slice(2)
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.8, 0.85, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.7, 0.7)
	var we := WorldEnvironment.new()
	we.environment = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var players := []
	var n := names.size()
	for i in n:
		var holder := Node3D.new()
		holder.position = Vector3((i - (n - 1) / 2.0) * 1.6, 0, 0)
		holder.rotation_degrees.y = 25
		root.add_child(holder)
		var m: Node3D = load("res://Assets/Character/student_character.glb").instantiate()
		holder.add_child(m)
		var ap: AnimationPlayer = m.get_node("AnimationPlayer")
		CharacterAnims.setup(ap, m)
		var l := Label3D.new()
		l.text = names[i]
		l.position = Vector3(0, -0.25, 0.5)
		l.font_size = 40
		l.modulate = Color.BLACK
		root.add_child(l)
		l.global_position = holder.global_position + Vector3(0, -0.25, 0.5)
		ap.play(names[i])
		players.append(ap)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.fov = 40
	cam.look_at_from_position(Vector3(0, 1.4, n * 1.6 * 0.72 + 1.2), Vector3(0, 0.9, 0))
	for k in 10: await process_frame
	for ap in players:
		ap.seek(ap.current_animation_length * t, true)
		ap.pause()
	for k in 5: await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
