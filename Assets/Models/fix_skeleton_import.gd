@tool
extends EditorScenePostImport

# Cactoro's glTF imports with an empty MeshInstance3D.skeleton path, so the mesh
# stays in T-pose while the bones animate. Re-link every skinned mesh to its skeleton.

func _post_import(scene: Node) -> Object:
	for mi in scene.find_children("*", "MeshInstance3D", true, false):
		if mi.skin != null and mi.skeleton.is_empty():
			var sk: Node = mi.get_parent() if mi.get_parent() is Skeleton3D else scene.find_child("Skeleton3D", true, false)
			if sk:
				mi.skeleton = mi.get_path_to(sk)
	return scene
