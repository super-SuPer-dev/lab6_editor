extends SceneTree
# usage: --script shot.gd -- <scene> <outprefix> "px,py,pz,tx,ty,tz" ...
func _initialize():
	var args := OS.get_cmdline_user_args()
	var scene: Node = load(args[0]).instantiate()
	root.add_child(scene)
	current_scene = scene
	for k in 30: await process_frame
	var i := 0
	for pose in args.slice(2):
		var v := Array(pose.split(",")).map(func(s): return float(s))
		var cam := Camera3D.new()
		cam.fov = 60
		cam.far = 1000
		root.add_child(cam)
		cam.look_at_from_position(Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5]))
		cam.make_current()
		for k in 8: await process_frame
		root.get_texture().get_image().save_png("%s_%d.png" % [args[1], i])
		cam.queue_free()
		i += 1
	if args.size() == 2:
		for k in 20: await process_frame
		root.get_texture().get_image().save_png("%s_play.png" % args[1])
	quit()
