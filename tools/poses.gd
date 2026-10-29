extends SceneTree
# Renders Cactoro in each animation at mid-time to check the clips really pose the skeleton.
func _initialize():
	var lib: AnimationLibrary = load("res://Assets/Animations/cactoro_anims.tres")
	var names := ["RESET-none", "Idle", "Run", "Jump", "Fall", "Flip", "Hurt", "Victory", "Death"]
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.8, 0.85, 0.9)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.8, 0.8, 0.8)
	var we := WorldEnvironment.new()
	we.environment = e
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var players := []
	for i in names.size():
		var holder := Node3D.new()
		holder.position = Vector3((i - 4) * 1.5, 0, 0)
		root.add_child(holder)
		var m: Node3D = load("res://Assets/Models/cactoro.glb").instantiate()
		m.name = "Model"
		m.scale = Vector3.ONE * 0.198
		holder.add_child(m)
		var l := Label3D.new()
		l.text = names[i]
		l.position = Vector3(0, -0.4, 0)
		l.font_size = 64
		l.modulate = Color.BLACK
		holder.add_child(l)
		if i > 0:
			var ap := AnimationPlayer.new()
			holder.add_child(ap)
			ap.root_node = NodePath("../Model")
			ap.add_animation_library("", lib)
			ap.play(names[i])
			players.append([ap, names[i]])
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.2, 7.4), Vector3(0, 0.7, 0))
	for k in 20: await process_frame
	for pr in players:
		var ap: AnimationPlayer = pr[0]
		ap.seek(ap.current_animation_length * 0.45, true)
		ap.pause()
	for k in 5: await process_frame
	root.get_texture().get_image().save_png("D:/D_Godot/Projects/lab5/shots/poses.png")
	quit()
