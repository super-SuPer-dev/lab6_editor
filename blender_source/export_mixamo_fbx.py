"""Export the body mesh only (no skeleton) as FBX with embedded textures for Mixamo auto-rigging.

Run:  blender --background student_character.blend --python export_mixamo_fbx.py
"""
import bpy
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "..", "mixamo_upload", "student_character_mixamo.fbx")

# Make every material fully matte: FBX carries specular/shininess over and
# Mixamo's viewer otherwise renders the character shiny like plastic.
for mat in bpy.data.materials:
    if not mat.use_nodes:
        continue
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
        bsdf.inputs["Roughness"].default_value = 1.0
        bsdf.inputs["Metallic"].default_value = 0.0

bpy.ops.object.select_all(action="DESELECT")
body = bpy.data.objects["StudentBody"]
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.fbx(
    filepath=OUT,
    use_selection=True,
    object_types={"MESH"},
    use_mesh_modifiers=False,
    path_mode="COPY",
    embed_textures=True,
    bake_anim=False,
)
print("DONE", OUT)
