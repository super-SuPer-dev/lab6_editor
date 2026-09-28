# Opens the character nicely framed in Material Preview (used for the report screenshot).
import bpy

def setup():
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            space = area.spaces.active
            space.shading.type = "MATERIAL"
            space.overlay.show_overlays = True
            r3d = space.region_3d
            r3d.view_perspective = "PERSP"
            from mathutils import Vector, Euler
            r3d.view_location = Vector((0, 0, 1.0))
            r3d.view_distance = 3.3
            r3d.view_rotation = Euler((1.4, 0, 0.45)).to_quaternion()
    for name in ("PreviewCamera", "Sun"):
        ob = bpy.data.objects.get(name)
        if ob:
            ob.hide_set(True)
    rig = bpy.data.objects.get("Armature")
    if rig:
        bpy.context.view_layer.objects.active = rig
        rig.select_set(True)
    return None

bpy.app.timers.register(setup, first_interval=1.5)
