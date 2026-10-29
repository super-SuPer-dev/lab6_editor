extends SceneTree
# Automated logic playtest: platforms, pits, traps, gems, doors, level flow.
var fails := 0
var gm: Node
func check(cond: bool, msg: String):
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond: fails += 1

func frames(n: int):
	for i in n: await physics_frame

func land_test(p: CharacterBody3D, spots: Array):
	for s in spots:
		p.global_position = s + Vector3(0, 1.2, 0)
		p.velocity = Vector3.ZERO
		await frames(45)
		check(p.is_on_floor() and absf(p.global_position.y - s.y) < 0.4, "lands on %s (y=%.2f)" % [s, p.global_position.y])

func play_level(path: String, spots: Array, next_check: String):
	change_scene_to_file(path)
	await frames(10)
	var lvl := current_scene
	check(lvl != null and lvl.scene_file_path == path, "loaded " + path)
	var p: CharacterBody3D = lvl.get_node("Player")
	await frames(40)
	check(gm.total == 8, "8 gems registered (got %d)" % gm.total)
	check(p.is_on_floor(), "player starts on floor")
	await land_test(p, spots)
	check(gm.hearts == 3, "no damage while visiting platforms (hearts=%d)" % gm.hearts)
	# pit -> lose a heart and respawn
	p.global_position = Vector3(30, -11, 30) if path.ends_with("1.tscn") else Vector3(14, -4.5, -20)
	await frames(30)
	check(gm.hearts == 2, "falling costs a heart (hearts=%d)" % gm.hearts)
	check(p.global_position.distance_to(gm.checkpoint) < 3.0, "respawned at checkpoint")
	# trap -> lose a heart
	await frames(100)
	var trap := lvl.get_node("Traps").get_child(0)
	var hz: Area3D = trap.find_children("*", "Area3D", true, false)[0]
	p.take_damage(hz.global_position)
	check(gm.hearts == 1, "trap costs a heart (hearts=%d)" % gm.hearts)
	# locked door
	var door: Area3D = lvl.get_node("Exit/Door")
	check(not door.is_open, "door locked at start")
	for g in lvl.get_node("Gems").get_children():
		g._on_body_entered(p)
	gm = root.get_node("GameManager")
	await frames(5)
	check(gm.score == 8, "all gems collected")
	check(door.is_open, "door opens after all gems")
	p.invincible_timer = 0
	p.global_position = door.global_position + door.global_transform.basis.z * 0.6 + Vector3.UP * 0.3
	await frames(200)
	check(current_scene != null and current_scene.scene_file_path == next_check, "door leads to " + next_check + " (now %s)" % (current_scene.scene_file_path if current_scene else "null"))

func _initialize():
	gm = root.get_node("GameManager")
	await frames(5)
	await play_level("res://Scenes/Levels/Level1.tscn", [
		Vector3(0, 0.8, -12), Vector3(6, 1.6, -19), Vector3(6, 1.6, -24), Vector3(6, 1.6, -44),
		Vector3(-15.5, 2.4, -44), Vector3(-27, 2.4, -44.9), Vector3(-42.5, 2.4, -47.5), Vector3(-42.5, 3.4, -35.4),
		Vector3(-38, 4.4, -31), Vector3(-42.5, 5.4, -26.5), Vector3(-48.5, 7.0, -26.5), Vector3(-42.5, 6.2, -20.5)],
		"res://Scenes/Levels/Level2.tscn")
	await play_level("res://Scenes/Levels/Level2.tscn", [
		Vector3(0, 0, -9.5), Vector3(3, 0.6, -14), Vector3(0, 1.2, -18.5), Vector3(0, 1.2, -42),
		Vector3(0, 1.2, -64), Vector3(6, 1.2, -64), Vector3(27, 1.2, -64), Vector3(27, 5.2, -77.5),
		Vector3(33.5, 6.8, -79), Vector3(27, 5.8, -89.5)],
		"res://Scenes/UI/Win.tscn")
	print("RESULT: %d failures" % fails)
	quit()
