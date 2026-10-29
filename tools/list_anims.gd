extends SceneTree
# Prints every animation in the Melee/Shooter libraries and the character's skeleton info.
func _init():
	for p in ["res://Assets/Animations/MeleeLib.res", "res://Assets/Animations/ShooterLib.res"]:
		var lib: AnimationLibrary = load(p)
		var out := []
		for n in lib.get_animation_list():
			var a := lib.get_animation(n)
			out.append("%s(%.2f%s)" % [n, a.length, "L" if a.loop_mode != Animation.LOOP_NONE else ""])
		print(p, ": ", ", ".join(out))
	var m: Node3D = load("res://Assets/Character/student_character.glb").instantiate()
	root.add_child(m)
	var sk: Skeleton3D = m.find_child("GeneralSkeleton", true, false)
	print("skeleton: ", sk, " bones=", sk.get_bone_count() if sk else 0)
	var aabb := AABB()
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		aabb = aabb.merge(mi.get_aabb()) if aabb.size != Vector3.ZERO else mi.get_aabb()
	print("mesh aabb: ", aabb)
	print("tree: "); m.print_tree_pretty()
	quit()
