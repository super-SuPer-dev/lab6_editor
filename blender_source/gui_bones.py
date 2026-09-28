# Shows the Mixamo-named skeleton with bone names (used for the report screenshot).
import bpy
from mathutils import Vector, Euler

def setup():
    for name in ("PreviewCamera", "Sun"):
        ob = bpy.data.objects.get(name)
        if ob:
            ob.hide_set(True)
    rig = bpy.data.objects["Armature"]
    rig.data.show_names = True
    rig.data.display_type = "OCTAHEDRAL"
    bpy.context.view_layer.objects.active = rig
    rig.select_set(True)
    for area in bpy.context.screen.areas:
        if area.type == "VIEW_3D":
            space = area.spaces.active
            space.shading.type = "SOLID"
            space.shading.show_xray = True
            r3d = space.region_3d
            r3d.view_perspective = "ORTHO"
            r3d.view_location = Vector((0, 0, 0.95))
            r3d.view_distance = 2.6
            r3d.view_rotation = Euler((1.5708, 0, 0)).to_quaternion()
    return None

bpy.app.timers.register(setup, first_interval=1.5)
