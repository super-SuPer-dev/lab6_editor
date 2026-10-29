extends SceneTree
# Prints a model's node tree, skeleton, posed height and animations.  usage: -- res://path
func _initialize():
	var m: Node3D = load(OS.get_cmdline_user_args()[0]).instantiate()
	root.add_child(m)
	await process_frame
	m.print_tree_pretty()
	for sk: Skeleton3D in m.find_children("*", "Skeleton3D", true, false):
		print(sk.name, " unique=", sk.unique_name_in_owner, " bones=", sk.get_bone_count())
		var lo := INF; var hi := -INF
		for b in sk.get_bone_count():
			var y := (sk.global_transform * sk.get_bone_global_pose(b)).origin.y
			lo = min(lo, y); hi = max(hi, y)
		print("bone y range: ", lo, " .. ", hi, "  head=", (sk.global_transform * sk.get_bone_global_pose(sk.find_bone("Head"))).origin)
	for ap in m.find_children("*", "AnimationPlayer", true, false):
		print("anims: ", ap.get_animation_list())
	quit()
