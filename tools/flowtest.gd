extends SceneTree
# Lab 6: Title -> character demo -> back to Title, and the demo's animation list.
func _initialize():
	change_scene_to_file("res://Scenes/UI/Title.tscn")
	for k in 20: await process_frame
	current_scene.get_node("UI/Menu/Panel/VBox/DemoButton").pressed.emit()
	for k in 90: await process_frame
	print("after demo button: ", current_scene.scene_file_path)
	var p = current_scene.get_node("Player")
	print("demo clips: ", p.get_all_animations().size())
	p.play_demo("melee/Slash1")
	for k in 10: await process_frame
	print("demo playing: ", p.anim.current_animation)
	var back: Button = current_scene.find_children("*", "Button", true, false)[0]
	back.pressed.emit()
	for k in 90: await process_frame
	print("after back: ", current_scene.scene_file_path)
	quit()
