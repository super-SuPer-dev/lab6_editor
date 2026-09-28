"""Build the Lab 6 student character in Blender and export it for Godot.

Run:  blender --background --python build_character.py
Outputs (next to this script):
  student_character.blend
  ../assets/character/student_character.glb
  face.jpg (copied photo used for the face)

The skeleton uses Mixamo bone names (mixamorig_*), so it works with the
"Mixamo BoneMap.tres" from Godot4-OpenAnimationLibraries.
"""
import bpy
import bmesh
import os
import shutil
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PHOTO_SRC = r"D:/D_Godot/all_godot_game/studentphoto.jpg"
PHOTO = os.path.join(HERE, "face.jpg")
BLEND_OUT = os.path.join(HERE, "student_character.blend")
GLB_OUT = os.path.join(HERE, "..", "assets", "character", "student_character.glb")

# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
if not os.path.exists(PHOTO):
    shutil.copy(PHOTO_SRC, PHOTO)

# ---------------------------------------------------------------- materials
def make_mat(name, color, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

MAT = {
    "skin": make_mat("Skin", (0.87, 0.66, 0.52)),
    "shirt": make_mat("Shirt", (0.93, 0.94, 0.96)),
    "pants": make_mat("Pants", (0.05, 0.05, 0.07)),
    "tie": make_mat("Tie", (0.05, 0.08, 0.25)),
    "hair": make_mat("Hair", (0.02, 0.02, 0.02), 0.5),
    "shoe": make_mat("Shoe", (0.08, 0.05, 0.03), 0.35),
    "belt": make_mat("Belt", (0.12, 0.10, 0.08), 0.4),
}

face_mat = bpy.data.materials.new("Face")
face_mat.use_nodes = True
nt = face_mat.node_tree
tex = nt.nodes.new("ShaderNodeTexImage")
img = bpy.data.images.load(PHOTO)
# Paint the blue photo background (around the hair) dark like the hair.
px = list(img.pixels)
for i in range(0, len(px), 4):
    r, g, b = px[i], px[i + 1], px[i + 2]
    if b > 0.35 and b > r + 0.2 and b > g + 0.05:
        px[i], px[i + 1], px[i + 2] = 0.03, 0.03, 0.035
img.pixels = px
img.filepath_raw = os.path.join(HERE, "face_texture.png")
img.file_format = "PNG"
img.save()
tex.image = img
nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
MAT["face"] = face_mat

# ---------------------------------------------------------------- skeleton
# Blender is Z-up, character faces -Y, character's left side is +X.
BONES = [
    # name, head, tail, parent
    ("mixamorig_Hips", (0, 0, 0.95), (0, 0, 1.05), None),
    ("mixamorig_Spine", (0, 0, 1.05), (0, 0, 1.17), "mixamorig_Hips"),
    ("mixamorig_Spine1", (0, 0, 1.17), (0, 0, 1.29), "mixamorig_Spine"),
    ("mixamorig_Spine2", (0, 0, 1.29), (0, 0, 1.44), "mixamorig_Spine1"),
    ("mixamorig_Neck", (0, 0, 1.44), (0, 0, 1.52), "mixamorig_Spine2"),
    ("mixamorig_Head", (0, 0, 1.52), (0, 0, 1.80), "mixamorig_Neck"),
    ("mixamorig_HeadTop_End", (0, 0, 1.80), (0, 0, 1.86), "mixamorig_Head"),
]
for side, s in (("Left", 1), ("Right", -1)):
    BONES += [
        (f"mixamorig_{side}Shoulder", (0.05 * s, 0, 1.40), (0.17 * s, 0, 1.41), "mixamorig_Spine2"),
        (f"mixamorig_{side}Arm", (0.17 * s, 0, 1.41), (0.44 * s, 0, 1.41), f"mixamorig_{side}Shoulder"),
        (f"mixamorig_{side}ForeArm", (0.44 * s, 0, 1.41), (0.69 * s, 0, 1.41), f"mixamorig_{side}Arm"),
        (f"mixamorig_{side}Hand", (0.69 * s, 0, 1.41), (0.79 * s, 0, 1.41), f"mixamorig_{side}ForeArm"),
        (f"mixamorig_{side}UpLeg", (0.10 * s, 0, 0.92), (0.10 * s, 0, 0.51), "mixamorig_Hips"),
        (f"mixamorig_{side}Leg", (0.10 * s, 0, 0.51), (0.10 * s, 0.01, 0.09), f"mixamorig_{side}UpLeg"),
        (f"mixamorig_{side}Foot", (0.10 * s, 0.01, 0.09), (0.10 * s, -0.10, 0.02), f"mixamorig_{side}Leg"),
        (f"mixamorig_{side}ToeBase", (0.10 * s, -0.10, 0.02), (0.10 * s, -0.18, 0.02), f"mixamorig_{side}Foot"),
    ]

arm_data = bpy.data.armatures.new("Armature")
rig = bpy.data.objects.new("Armature", arm_data)
bpy.context.scene.collection.objects.link(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for name, head, tail, parent in BONES:
    b = arm_data.edit_bones.new(name)
    b.head, b.tail = Vector(head), Vector(tail)
    if parent:
        b.parent = arm_data.edit_bones[parent]
        b.use_connect = (Vector(head) - arm_data.edit_bones[parent].tail).length < 1e-4
bpy.ops.object.mode_set(mode="OBJECT")
arm_data.display_type = "STICK"
rig.show_in_front = True

BONE_SEG = {n: (Vector(h), Vector(t)) for n, h, t, _ in BONES}


def seg_dist(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
    return (a + ab * t - p).length


# ---------------------------------------------------------------- mesh parts
parts = []


def add_part(obj, mat, bones):
    """Give obj a material and smooth weights over the candidate bones."""
    obj.data.materials.append(MAT[mat])
    groups = {b: obj.vertex_groups.new(name=b) for b in bones}
    for v in obj.data.vertices:
        p = obj.matrix_world @ v.co
        d = {b: seg_dist(p, *BONE_SEG[b]) for b in bones}
        best = sorted(d, key=d.get)[:2]
        if len(best) == 1:
            groups[best[0]].add([v.index], 1.0, "REPLACE")
            continue
        d0, d1 = d[best[0]] + 1e-4, d[best[1]] + 1e-4
        # Sharp falloff: mostly rigid, soft blend only near joints.
        w0, w1 = (1 / d0) ** 4, (1 / d1) ** 4
        s = w0 + w1
        groups[best[0]].add([v.index], w0 / s, "REPLACE")
        groups[best[1]].add([v.index], w1 / s, "REPLACE")
    parts.append(obj)
    return obj


def box(name, center, size, bevel=0.02, segs=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    o = bpy.context.object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    if bevel:
        bm = bmesh.new()
        bm.from_mesh(o.data)
        bmesh.ops.bevel(bm, geom=bm.edges[:], offset=bevel, segments=segs, affect="EDGES")
        bm.to_mesh(o.data)
        bm.free()
    return o


def limb(name, a, b, r0, r1, verts=12, cuts=6):
    """Tapered capsule-ish cylinder from point a to point b."""
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=1, depth=1, location=(0, 0, 0))
    o = bpy.context.object
    o.name = name
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.5],
                              cuts=cuts, use_grid_fill=True)
    for v in bm.verts:
        t = v.co.z + 0.5  # 0..1 along the limb
        r = r0 + (r1 - r0) * t
        # round the ends a little
        end = min(t, 1 - t)
        if end < 0.12:
            r *= 0.75 + 0.25 * (end / 0.12)
        v.co.x *= r
        v.co.y *= r
    bm.to_mesh(o.data)
    bm.free()
    length = (b - a).length
    o.scale = (1, 1, length)
    o.location = (a + b) / 2
    o.rotation_mode = "QUATERNION"
    o.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(b - a)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.shade_smooth()
    return o


SPINE = ["mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2"]

# Torso (shirt) and pelvis (pants)
torso = box("Torso", (0, 0, 1.22), (0.36, 0.21, 0.46), bevel=0.06, segs=3)
bm = bmesh.new(); bm.from_mesh(torso.data)
bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.z - e.verts[1].co.z) > 0.2], cuts=5)
for v in bm.verts:  # wider chest, narrower waist
    k = 0.88 + 0.22 * max(0.0, min(1.0, (v.co.z - 1.0) / 0.4))
    v.co.x *= k
bm.to_mesh(torso.data); bm.free()
add_part(torso, "shirt", SPINE + ["mixamorig_Neck"])

pelvis = box("Pelvis", (0, 0, 0.93), (0.34, 0.21, 0.16), bevel=0.05, segs=3)
add_part(pelvis, "pants", ["mixamorig_Hips", "mixamorig_LeftUpLeg", "mixamorig_RightUpLeg"])
belt = box("Belt", (0, 0, 1.005), (0.345, 0.215, 0.035), bevel=0.01, segs=1)
add_part(belt, "belt", ["mixamorig_Hips"])

# Collar and tie
collar = box("Collar", (0, -0.02, 1.445), (0.18, 0.17, 0.04), bevel=0.015)
add_part(collar, "shirt", ["mixamorig_Spine2", "mixamorig_Neck"])
tie_knot = box("TieKnot", (0, -0.112, 1.415), (0.045, 0.02, 0.04), bevel=0.008, segs=1)
add_part(tie_knot, "tie", ["mixamorig_Spine2"])
tie = box("Tie", (0, -0.112, 1.25), (0.06, 0.012, 0.30), bevel=0.004, segs=1)
bm = bmesh.new(); bm.from_mesh(tie.data)
for v in bm.verts:  # taper up, pointed tip down
    v.co.x *= 0.6 + 0.4 * (1.0 - (v.co.z - 1.10) / 0.30)
    if v.co.z < 1.11:
        v.co.z -= 0.03 * (1 - abs(v.co.x) / 0.035)
bm.to_mesh(tie.data); bm.free()
add_part(tie, "tie", SPINE[1:])

# Neck
neck = limb("Neck", (0, 0, 1.42), (0, 0, 1.56), 0.055, 0.05)
add_part(neck, "skin", ["mixamorig_Neck", "mixamorig_Head"])

# Head: front face shows the photo, the rest is skin
HEAD_W, HEAD_H, HEAD_D = 0.29, 0.34, 0.29
HEAD_C = Vector((0, 0.0, 1.715))
head = box("Head", HEAD_C, (HEAD_W, HEAD_D, HEAD_H), bevel=0.03, segs=3)
head.data.materials.append(MAT["skin"])
head.data.materials.append(MAT["face"])
bm = bmesh.new(); bm.from_mesh(head.data)
uv = bm.loops.layers.uv.verify()
# Photo is 198x298. Crop that covers hair line to chin.
IMG_W, IMG_H = 198, 298
X0, X1, Y0, Y1 = 52, 146, 30, 172
for f in bm.faces:
    if f.normal.y < -0.9:  # front
        f.material_index = 1
        for l in f.loops:
            u = (l.vert.co.x - (HEAD_C.x - HEAD_W / 2)) / HEAD_W
            w = (l.vert.co.z - (HEAD_C.z - HEAD_H / 2)) / HEAD_H
            l[uv].uv = ((X0 + u * (X1 - X0)) / IMG_W, 1 - (Y1 - w * (Y1 - Y0)) / IMG_H)
bm.to_mesh(head.data); bm.free()
groups = head.vertex_groups.new(name="mixamorig_Head")
groups.add([v.index for v in head.data.vertices], 1.0, "REPLACE")
parts.append(head)

# Hair: cap over top, sides and back (front left open for the photo)
hair_top = box("HairTop", HEAD_C + Vector((0, 0.01, HEAD_H / 2 + 0.005)), (HEAD_W + 0.03, HEAD_D + 0.04, 0.06), bevel=0.025)
add_part(hair_top, "hair", ["mixamorig_Head"])
hair_back = box("HairBack", HEAD_C + Vector((0, HEAD_D / 2 + 0.01, 0.04)), (HEAD_W + 0.03, 0.04, HEAD_H * 0.8), bevel=0.02)
add_part(hair_back, "hair", ["mixamorig_Head"])
for s in (1, -1):
    side = box(f"HairSide{s}", HEAD_C + Vector((s * (HEAD_W / 2 + 0.012), 0.03, 0.07)), (0.03, HEAD_D * 0.8, HEAD_H * 0.55), bevel=0.012)
    add_part(side, "hair", ["mixamorig_Head"])

# Arms / legs
for side, s in (("Left", 1), ("Right", -1)):
    B = lambda n: f"mixamorig_{side}{n}"
    sh = limb(f"{side}ShoulderPad", (0.10 * s, 0, 1.40), (0.20 * s, 0, 1.41), 0.07, 0.065)
    add_part(sh, "shirt", [B("Shoulder"), B("Arm"), "mixamorig_Spine2"])
    ua = limb(f"{side}UpperArm", (0.16 * s, 0, 1.41), (0.46 * s, 0, 1.41), 0.062, 0.052)
    add_part(ua, "shirt", [B("Shoulder"), B("Arm"), B("ForeArm")])
    fa = limb(f"{side}ForeArm", (0.42 * s, 0, 1.41), (0.68 * s, 0, 1.41), 0.052, 0.042)
    add_part(fa, "shirt", [B("Arm"), B("ForeArm"), B("Hand")])
    cuff = limb(f"{side}Cuff", (0.64 * s, 0, 1.41), (0.685 * s, 0, 1.41), 0.047, 0.047)
    add_part(cuff, "shirt", [B("ForeArm")])
    hand = box(f"{side}Hand", (0.745 * s, 0, 1.405), (0.12, 0.09, 0.035), bevel=0.015)
    add_part(hand, "skin", [B("Hand")])
    thumb = box(f"{side}Thumb", (0.72 * s, -0.055, 1.40), (0.05, 0.03, 0.025), bevel=0.01, segs=1)
    add_part(thumb, "skin", [B("Hand")])

    ul = limb(f"{side}Thigh", (0.10 * s, 0, 0.96), (0.10 * s, 0, 0.50), 0.085, 0.066)
    add_part(ul, "pants", ["mixamorig_Hips", B("UpLeg"), B("Leg")])
    ll = limb(f"{side}Shin", (0.10 * s, 0, 0.53), (0.10 * s, 0.01, 0.08), 0.066, 0.052)
    add_part(ll, "pants", [B("UpLeg"), B("Leg"), B("Foot")])
    shoe = box(f"{side}Shoe", (0.10 * s, -0.05, 0.045), (0.11, 0.27, 0.09), bevel=0.035, segs=3)
    add_part(shoe, "shoe", [B("Foot"), B("ToeBase")])

# ---------------------------------------------------------------- join + skin
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.object
body.name = "StudentBody"
body.data.name = "StudentBody"
body.parent = rig
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = rig

# ---------------------------------------------------------------- T-pose action
bpy.context.view_layer.objects.active = rig
rig.animation_data_create()
action = bpy.data.actions.new("TPose")
rig.animation_data.action = action
bpy.ops.object.mode_set(mode="POSE")
for pb in rig.pose.bones:
    pb.rotation_mode = "QUATERNION"
    for f in (1, 2):
        pb.keyframe_insert("location", frame=f)
        pb.keyframe_insert("rotation_quaternion", frame=f)
bpy.ops.object.mode_set(mode="OBJECT")
bpy.context.scene.frame_end = 2

# ---------------------------------------------------------------- nice preview setup
bpy.ops.object.camera_add(location=(2.2, -3.4, 1.5))
cam = bpy.context.object
cam.name = "PreviewCamera"
direction = Vector((0, 0, 1.0)) - cam.location
cam.rotation_mode = "QUATERNION"
cam.rotation_quaternion = direction.to_track_quat("-Z", "Y")
bpy.context.scene.camera = cam
bpy.ops.object.light_add(type="SUN", location=(2, -2, 4))
bpy.context.object.data.energy = 3.0
bpy.context.object.rotation_euler = (0.8, 0.2, 0.6)
world = bpy.data.worlds.new("World")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.45, 0.6, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
bpy.context.scene.world = world

bpy.ops.wm.save_as_mainfile(filepath=BLEND_OUT)

# ---------------------------------------------------------------- export glb
os.makedirs(os.path.dirname(GLB_OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
body.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=GLB_OUT,
    export_format="GLB",
    use_selection=True,
    export_animations=True,
    export_skins=True,
    export_yup=True,
)
print("DONE", GLB_OUT)
