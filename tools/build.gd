extends SceneTree

# Generates the Lab 5 scenes (player, prefabs, Level1, Level2, Title, Win) as .tscn files.
# Lab 6: the player / title / win hero is now the student character (hero_with_anims).
# Run: tools/rebuild.sh  (from the project folder)

const PP := "res://Assets/Models/PolyPizza/"
var rng := RandomNumberGenerator.new()
var vc_mat: StandardMaterial3D
var font_bold: FontFile
var font_semi: FontFile
var anim_lib: AnimationLibrary

# ============================================================ helpers

func own(n: Node, root: Node):
	for c in n.get_children():
		c.owner = root
		if c.scene_file_path == "":
			own(c, root)

func save_scene(root: Node, path: String):
	own(root, root)
	var ps := PackedScene.new()
	var err := ps.pack(root)
	if err != OK:
		push_error("pack failed " + path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	err = ResourceSaver.save(ps, path)
	print("saved ", path, " err=", err)
	root.free()

func load_fresh(path: String) -> PackedScene:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

func add(parent: Node, child: Node, name := "") -> Node:
	if name != "":
		child.name = name
	parent.add_child(child)
	return child

func aabb_of(n: Node, xf := Transform3D()) -> AABB:
	var out := AABB()
	var first := true
	var t := xf
	if n is Node3D:
		t = xf * (n as Node3D).transform
	if n is MeshInstance3D and n.mesh:
		out = t * n.mesh.get_aabb()
		first = false
	for c in n.get_children():
		var ca := aabb_of(c, t)
		if ca.size != Vector3.ZERO:
			out = ca if first else out.merge(ca)
			first = false
	return out

# Instance a Poly Pizza model scaled to a target height
func model(file: String, height: float, pos := Vector3.ZERO, rot_y := 0.0) -> Node3D:
	var path := file if file.begins_with("res://") else PP + file + ".glb"
	var inst: Node3D = load(path).instantiate()
	var bb := aabb_of(inst)
	var s := height / maxf(bb.size.y, 0.001)
	inst.scale = Vector3.ONE * s
	inst.position = pos
	inst.rotation_degrees.y = rot_y
	inst.name = file.get_file().get_basename().to_pascal_case()
	return inst

func box_shape(size: Vector3, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	return cs

func sphere_shape(r: float, pos := Vector3.ZERO) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = r
	cs.shape = s
	cs.position = pos
	return cs

func vary(c: Color, amt := 0.04) -> Color:
	var v := rng.randf_range(-amt, amt)
	return Color(clamp(c.r + v, 0, 1), clamp(c.g + v, 0, 1), clamp(c.b + v * 0.8, 0, 1))

# Flat-shaded triangle; flips winding so the face points along `out`
func tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, out: Vector3):
	var n := (c - a).cross(b - a)
	if n.dot(out) < 0:
		var tmp := b
		b = c
		c = tmp
		n = -n
	n = n.normalized()
	for v in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(v)

func quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, out: Vector3):
	tri(st, a, b, c, col, out)
	tri(st, a, c, d, col, out)

# ============================================================ procedural low-poly meshes

# Floating island / column. rings: [[y, radius_factor], ...] from top down; colors per band.
func island_mesh(radius: float, sides: int, rings: Array, band_cols: Array, top_col: Color, jitter := 0.08) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var off := rng.randf() * TAU
	var ring_pts := []
	var jit := []
	for k in sides:
		jit.append(1.0 + rng.randf_range(-jitter, jitter))
	for i in rings.size():
		var pts := []
		var y: float = rings[i][0]
		var rf: float = rings[i][1]
		for k in sides:
			var a := off + TAU * k / sides + (rng.randf_range(-0.08, 0.08) if i > 1 else 0.0)
			var j: float = jit[k] if i < 2 else 1.0 + rng.randf_range(-jitter, jitter)
			pts.append(Vector3(cos(a) * radius * rf * j, y + (rng.randf_range(-0.12, 0.12) if i > 1 else 0.0), sin(a) * radius * rf * j))
		ring_pts.append(pts)
	# top cap
	var center := Vector3.ZERO
	for k in sides:
		tri(st, center, ring_pts[0][k], ring_pts[0][(k + 1) % sides], vary(top_col, 0.025), Vector3.UP)
	# side bands
	for i in rings.size() - 1:
		var col: Color = band_cols[min(i, band_cols.size() - 1)]
		for k in sides:
			var a: Vector3 = ring_pts[i][k]
			var b: Vector3 = ring_pts[i][(k + 1) % sides]
			var c: Vector3 = ring_pts[i + 1][(k + 1) % sides]
			var d: Vector3 = ring_pts[i + 1][k]
			var mid := (a + b + c + d) / 4.0
			quad(st, a, b, c, d, vary(col, 0.03), Vector3(mid.x, 0, mid.z))
	# bottom tip
	var last: Array = ring_pts[rings.size() - 1]
	var tip := Vector3(0, float(rings[rings.size() - 1][0]) - radius * 0.25, 0)
	var bcol: Color = band_cols[band_cols.size() - 1]
	for k in sides:
		tri(st, last[k], last[(k + 1) % sides], tip, vary(bcol.darkened(0.15), 0.03), Vector3.DOWN)
	st.set_material(vc_mat)
	return st.commit()

# Box with a different top color. Origin at the center of the top face.
func slab_mesh(size: Vector3, top_col: Color, side_col: Color, st_in: SurfaceTool = null, offset := Vector3.ZERO) -> ArrayMesh:
	var st := st_in if st_in else SurfaceTool.new()
	if st_in == null:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := size / 2.0
	var o := offset + Vector3(0, -h.y, 0)
	var p := func(x, y, z): return o + Vector3(x * h.x, y * h.y, z * h.z)
	quad(st, p.call(-1, 1, -1), p.call(1, 1, -1), p.call(1, 1, 1), p.call(-1, 1, 1), vary(top_col, 0.03), Vector3.UP)
	quad(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, -1, 1), p.call(-1, -1, 1), side_col.darkened(0.25), Vector3.DOWN)
	quad(st, p.call(-1, -1, 1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(-1, 1, 1), side_col, Vector3.BACK)
	quad(st, p.call(-1, -1, -1), p.call(1, -1, -1), p.call(1, 1, -1), p.call(-1, 1, -1), side_col, Vector3.FORWARD)
	quad(st, p.call(1, -1, -1), p.call(1, -1, 1), p.call(1, 1, 1), p.call(1, 1, -1), side_col.darkened(0.08), Vector3.RIGHT)
	quad(st, p.call(-1, -1, -1), p.call(-1, -1, 1), p.call(-1, 1, 1), p.call(-1, 1, -1), side_col.darkened(0.08), Vector3.LEFT)
	if st_in == null:
		st.set_material(vc_mat)
		return st.commit()
	return null

# Bridge made of planks (wood) or tiles (stone) laid along local -Z
func planks_mesh(length: float, width: float, cols: Array, plank := 0.7, gap := 0.07, thick := 0.45) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(ceil(length / plank))
	var step := length / n
	for i in n:
		var z := -step * (i + 0.5) + length / 2.0
		var c: Color = cols[i % cols.size()]
		var dy := rng.randf_range(-0.03, 0.0)
		slab_mesh(Vector3(width + rng.randf_range(-0.1, 0.1), thick, step - gap), c.lightened(0.08), c.darkened(0.1), st, Vector3(0, dy, z))
	# side beams
	for sx in [-1, 1]:
		slab_mesh(Vector3(0.25, 0.3, length), cols[0].darkened(0.35), cols[0].darkened(0.45), st, Vector3(sx * (width / 2.0 + 0.05), -thick + 0.1, 0))
	st.set_material(vc_mat)
	return st.commit()

func dunes_mesh(size: float, cells: int, y_scale: float, cols: Array) -> ArrayMesh:
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.012
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step := size / cells
	var hgt := func(x, z): return noise.get_noise_2d(x, z) * y_scale
	for i in cells:
		for j in cells:
			var x0 := -size / 2 + i * step
			var z0 := -size / 2 + j * step
			var a := Vector3(x0, hgt.call(x0, z0), z0)
			var b := Vector3(x0 + step, hgt.call(x0 + step, z0), z0)
			var c := Vector3(x0 + step, hgt.call(x0 + step, z0 + step), z0 + step)
			var d := Vector3(x0, hgt.call(x0, z0 + step), z0 + step)
			var t1 := clampf((a.y + b.y + c.y) / 3.0 / y_scale * 0.5 + 0.5, 0.0, 1.0)
			var t2 := clampf((a.y + c.y + d.y) / 3.0 / y_scale * 0.5 + 0.5, 0.0, 1.0)
			tri(st, a, b, c, vary((cols[0] as Color).lerp(cols[1], t1), 0.02), Vector3.UP)
			tri(st, a, c, d, vary((cols[0] as Color).lerp(cols[1], t2), 0.02), Vector3.UP)
	st.set_material(vc_mat)
	return st.commit()

func cone_mesh(radius: float, height: float, sides: int, col: Color, top_col: Color, crater := 0.25) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bottom := []
	var top := []
	for k in sides:
		var a := TAU * k / sides
		var j := 1.0 + rng.randf_range(-0.1, 0.1)
		bottom.append(Vector3(cos(a) * radius * j, 0, sin(a) * radius * j))
		top.append(Vector3(cos(a) * radius * crater * j, height * rng.randf_range(0.95, 1.02), sin(a) * radius * crater * j))
	for k in sides:
		var a: Vector3 = bottom[k]
		var b: Vector3 = bottom[(k + 1) % sides]
		var c: Vector3 = top[(k + 1) % sides]
		var d: Vector3 = top[k]
		var mid := (a + b + c + d) / 4
		quad(st, a, b, c, d, vary(col, 0.04), Vector3(mid.x, 0.3, mid.z))
		tri(st, Vector3(0, height * 0.85, 0), top[k], top[(k + 1) % sides], top_col, Vector3.UP)
	st.set_material(vc_mat)
	return st.commit()

# ============================================================ animation library (Gobot names -> Cactoro clips)

func build_anim_library():
	var glb: Node = load("res://Assets/Models/cactoro.glb").instantiate()
	var ap: AnimationPlayer = glb.find_child("AnimationPlayer")
	var lib := AnimationLibrary.new()
	var map := {
		"Idle": ["CharacterArmature|Idle", Animation.LOOP_LINEAR],
		"Run": ["CharacterArmature|Run", Animation.LOOP_LINEAR],
		"Jump": ["CharacterArmature|Jump", Animation.LOOP_NONE],
		"Fall": ["CharacterArmature|Jump_Idle", Animation.LOOP_LINEAR],
		"Land": ["CharacterArmature|Jump_Land", Animation.LOOP_NONE],
		"Hurt": ["CharacterArmature|HitReact", Animation.LOOP_NONE],
		"Death": ["CharacterArmature|Death", Animation.LOOP_NONE],
		"Victory": ["CharacterArmature|Wave", Animation.LOOP_LINEAR],
		"Walk": ["CharacterArmature|Walk", Animation.LOOP_LINEAR],
	}
	for new_name in map:
		var a: Animation = ap.get_animation(map[new_name][0]).duplicate(true)
		a.loop_mode = map[new_name][1]
		lib.add_animation(new_name, a)
	# Flip = the airborne pose + a full forward somersault of the whole model
	var flip: Animation = ap.get_animation("CharacterArmature|Jump_Idle").duplicate(true)
	flip.loop_mode = Animation.LOOP_NONE
	flip.length = 0.6
	var pivot := Vector3(0, 1.4, 0) # middle of the body in model space
	var rt := flip.add_track(Animation.TYPE_ROTATION_3D)
	flip.track_set_path(rt, "RootNode")
	var pt := flip.add_track(Animation.TYPE_POSITION_3D)
	flip.track_set_path(pt, "RootNode")
	for i in 9:
		var t := i / 8.0
		var ang := TAU * ease(t, -1.6)
		var q := Quaternion(Vector3.RIGHT, ang)
		flip.rotation_track_insert_key(rt, t * flip.length, q)
		flip.position_track_insert_key(pt, t * flip.length, pivot - q * pivot)
	lib.add_animation("Flip", flip)
	# RESET keeps the root upright when another clip interrupts the flip
	var reset := Animation.new()
	reset.length = 0.01
	var r2 := reset.add_track(Animation.TYPE_ROTATION_3D)
	reset.track_set_path(r2, "RootNode")
	reset.rotation_track_insert_key(r2, 0, Quaternion.IDENTITY)
	var p2 := reset.add_track(Animation.TYPE_POSITION_3D)
	reset.track_set_path(p2, "RootNode")
	reset.position_track_insert_key(p2, 0, Vector3.ZERO)
	lib.add_animation("RESET", reset)
	DirAccess.make_dir_recursive_absolute("res://Assets/Animations")
	ResourceSaver.save(lib, "res://Assets/Animations/cactoro_anims.tres")
	glb.free()
	anim_lib = load_fresh_res("res://Assets/Animations/cactoro_anims.tres")

func load_fresh_res(path: String) -> Resource:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)

# Lab 6: student character; its clips are added at runtime by CharacterAnims.setup()
func hero_with_anims(root: Node3D):
	var m := model("res://Assets/Character/student_character.glb", 1.0)
	m.scale = Vector3.ONE * 0.78  # 1.92 m model -> ~1.5 m, the size the levels were built for
	m.name = "Model"
	root.add_child(m)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	ap.root_node = NodePath("../Model")
	root.add_child(ap)

# ============================================================ prefabs

func build_player():
	# Camera rig / dust trail were taken from the kit player (Gobot); later rebuilds reuse them from player.tscn
	var src := "res://Scenes/_kit_player.tscn" if FileAccess.file_exists("res://Scenes/_kit_player.tscn") else "res://Scenes/player.tscn"
	var old: Node = load(src).instantiate()
	var p := CharacterBody3D.new()
	p.name = "Player"
	p.add_to_group("Player", true)
	p.set_script(load("res://Scripts/player.gd"))
	p.floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.32
	cap.height = 1.5
	cs.shape = cap
	cs.position = Vector3(0, 0.75, 0)
	add(p, cs, "CollisionShape3D")
	hero_with_anims(p)
	(p.get_node("Model") as Node3D).rotation_degrees.y = 180
	# Camera rig, dust trail and footsteps come straight from the starter kit
	for n in ["Gimbal", "ParticleTrail"]:
		var d: Node = old.get_node(n).duplicate()
		p.add_child(d)
	var gimbal: Node3D = p.get_node("Gimbal")
	gimbal.unique_name_in_owner = true
	gimbal.position = Vector3(0, 1, 0)
	var cam: Camera3D = gimbal.get_node("Camera3D")
	cam.position = Vector3(0, 2.4, 6.2)
	cam.rotation_degrees = Vector3(-14, 0, 0)
	cam.fov = 70
	cam.far = 900
	var timer: Timer = gimbal.get_node("CameraControlTimer")
	for c in timer.timeout.get_connections():
		timer.timeout.disconnect(c.callable)
	timer.timeout.connect(Callable(gimbal, "_on_camera_control_timer_timeout"), CONNECT_PERSIST)
	old.free()
	save_scene(p, "res://Scenes/player.tscn")

func sparkles(color: Color, amount := 8) -> CPUParticles3D:
	var sp := CPUParticles3D.new()
	sp.amount = amount
	var q := QuadMesh.new()
	q.size = Vector2(0.15, 0.15)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = load("res://Assets/Textures/particle.png")
	m.vertex_color_use_as_albedo = true
	q.material = m
	sp.mesh = q
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.6
	sp.gravity = Vector3(0, 0.6, 0)
	sp.initial_velocity_max = 0.4
	sp.color = color
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.5, 1))
	curve.add_point(Vector2(1, 0))
	sp.scale_amount_curve = curve
	return sp

func build_gem(path: String, glb: String, color: Color):
	var g := Area3D.new()
	g.name = "Gem"
	g.set_script(load("res://Scripts/Coin.gd"))
	var m := model(glb, 0.95)
	add(g, m, "GemModel")
	add(g, sphere_shape(0.7), "CollisionShape3D")
	add(g, sparkles(color, 10), "Sparkles")
	var rng_area := Area3D.new()
	add(g, rng_area, "Range")
	add(rng_area, sphere_shape(2.4), "CollisionShape3D")
	save_scene(g, path)

func build_checkpoint():
	var a := Area3D.new()
	a.name = "Checkpoint"
	a.set_script(load("res://Scripts/Checkpoint.gd"))
	add(a, box_shape(Vector3(2.4, 3, 2.4), Vector3(0, 1.5, 0)), "CollisionShape3D")
	var base := MeshInstance3D.new()
	base.mesh = island_mesh(0.9, 7, [[0.12, 1.0], [0.0, 1.0], [-0.05, 1.05]], [Color(0.45, 0.42, 0.4)], Color(0.62, 0.6, 0.56), 0.03)
	add(a, base, "Base")
	var flag := model("res://Assets/Models/flag.glb", 2.6, Vector3(0, 0.1, 0))
	add(a, flag, "Flag")
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 1.0, 0.55)
	l.light_energy = 1.4
	l.omni_range = 5.0
	l.position = Vector3(0, 2, 0.6)
	add(a, l, "Light")
	var b := sparkles(Color(0.7, 1.0, 0.5), 30)
	b.one_shot = true
	b.emitting = false
	b.explosiveness = 0.9
	b.initial_velocity_min = 2.0
	b.initial_velocity_max = 4.0
	b.gravity = Vector3(0, -3, 0)
	b.position = Vector3(0, 1.5, 0)
	b.scale_amount_min = 2.0
	b.scale_amount_max = 2.5
	add(a, b, "Burst")
	save_scene(a, "res://Scenes/Prefabs/Checkpoint.tscn")

func build_door():
	var d := Area3D.new()
	d.name = "Door"
	d.set_script(load("res://Scripts/Door.gd"))
	add(d, box_shape(Vector3(2.4, 3.0, 2.2), Vector3(0, 1.5, 0.6)), "CollisionShape3D")
	var arch := model("arch", 4.6)
	add(d, arch, "Arch")
	var aw := aabb_of(arch).size.x
	var pivot := Node3D.new()
	pivot.position = Vector3(-1.2, 0, 0.05)
	add(d, pivot, "DoorPivot")
	var door := model("arch_door", 3.3, Vector3(1.2, 0, 0))
	pivot.add_child(door)
	var dw := aabb_of(door).size.x
	door.scale.x *= 2.4 / dw
	var portal := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	var sm := ShaderMaterial.new()
	sm.shader = load("res://Assets/Shaders/portal.gdshader")
	q.material = sm
	portal.mesh = q
	portal.position = Vector3(0, 1.6, -0.1)
	add(d, portal, "Portal")
	var l := OmniLight3D.new()
	l.light_energy = 1.5
	l.omni_range = 7.0
	l.position = Vector3(0, 2.4, 1.6)
	add(d, l, "Light")
	var sign := Label3D.new()
	sign.font = font_bold
	sign.font_size = 56
	sign.outline_size = 14
	sign.outline_modulate = Color(0.2, 0.08, 0.04)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = Vector3(0, 5.6, 0.3)
	sign.pixel_size = 0.012
	sign.text = "ประตูล็อก"
	add(d, sign, "Sign")
	var blocker := StaticBody3D.new()
	add(d, blocker, "Blocker")
	add(blocker, box_shape(Vector3(2.6, 3.4, 0.5), Vector3(0, 1.7, 0)), "CollisionShape3D")
	print("door: arch width ", aw, " door width ", dw)
	save_scene(d, "res://Scenes/Prefabs/Door.tscn")

func build_spikes():
	var r := Node3D.new()
	r.name = "PopUpSpikes"
	r.set_script(load("res://Scripts/Traps/PopUpSpikes.gd"))
	var hole := MeshInstance3D.new()
	hole.mesh = slab_mesh(Vector3(1.9, 0.05, 1.9), Color(0.18, 0.12, 0.1), Color(0.18, 0.12, 0.1))
	hole.position = Vector3(0, 0.03, 0)
	add(r, hole, "Hole")
	var sp := Node3D.new()
	add(r, sp, "Spikes")
	var m := model("spike_platform", 1.3)
	m.scale.x *= 1.05
	m.scale.z *= 1.05
	sp.add_child(m)
	var hz := Area3D.new()
	hz.set_script(load("res://Scripts/Traps/Hazard.gd"))
	add(sp, hz, "Hazard")
	add(hz, box_shape(Vector3(1.6, 0.9, 1.6), Vector3(0, 0.75, 0)), "CollisionShape3D")
	save_scene(r, "res://Scenes/Prefabs/PopUpSpikes.tscn")

func build_pendulum():
	var r := Node3D.new()
	r.name = "Pendulum"
	r.set_script(load("res://Scripts/Traps/Pendulum.gd"))
	var anchor := MeshInstance3D.new()
	anchor.mesh = island_mesh(0.9, 6, [[0.3, 0.7], [0.0, 1.0], [-0.5, 0.6]], [Color(0.35, 0.3, 0.3), Color(0.25, 0.22, 0.22)], Color(0.45, 0.4, 0.38), 0.1)
	anchor.position = Vector3(0, 6.5, 0)
	add(r, anchor, "Anchor")
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 6.2, 0)
	add(r, pivot, "Pivot")
	var chain := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.07
	cyl.bottom_radius = 0.07
	cyl.height = 5.2
	cyl.radial_segments = 6
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.3, 0.3, 0.32)
	cm.metallic = 0.6
	cm.roughness = 0.4
	cyl.material = cm
	chain.mesh = cyl
	chain.position = Vector3(0, -2.6, 0)
	add(pivot, chain, "Chain")
	var ball := model("spiky_ball", 1.4, Vector3(0, -5.3, 0))
	add(pivot, ball, "SpikyBall")
	var hz := Area3D.new()
	hz.set_script(load("res://Scripts/Traps/Hazard.gd"))
	hz.position = Vector3(0, -5.3, 0)
	add(pivot, hz, "Hazard")
	add(hz, sphere_shape(0.65), "CollisionShape3D")
	save_scene(r, "res://Scenes/Prefabs/Pendulum.tscn")

func build_spinner():
	var r := Node3D.new()
	r.name = "Spinner"
	r.set_script(load("res://Scripts/Traps/Spinner.gd"))
	r.set("rotate_child", "Rotor")
	r.set("degrees_per_second", 70.0)
	var post := model("column", 1.6)
	post.scale.x *= 0.7
	post.scale.z *= 0.7
	add(r, post, "Post")
	var rotor := Node3D.new()
	rotor.position = Vector3(0, 0.55, 0)
	add(r, rotor, "Rotor")
	for side in [-1, 1]:
		var arm := model("cylinder_hazard", 4.0)
		arm.scale = Vector3(arm.scale.x * 0.33, arm.scale.y, arm.scale.z * 0.33)
		arm.rotation_degrees = Vector3(0, 0, -90 * side)
		arm.position = Vector3(0.35 * side, 0, 0)
		arm.name = "Arm" + ("L" if side < 0 else "R")
		rotor.add_child(arm)
		var hz := Area3D.new()
		hz.set_script(load("res://Scripts/Traps/Hazard.gd"))
		hz.position = Vector3(2.35 * side, 0, 0)
		add(rotor, hz, "Hazard" + ("L" if side < 0 else "R"))
		add(hz, box_shape(Vector3(3.9, 0.75, 0.75)), "CollisionShape3D")
	save_scene(r, "res://Scenes/Prefabs/Spinner.tscn")

func build_roller():
	var r := Node3D.new()
	r.name = "RollingBall"
	r.set_script(load("res://Scripts/Traps/Mover.gd"))
	var roll := Node3D.new()
	roll.set_script(load("res://Scripts/Traps/Spinner.gd"))
	roll.set("axis", Vector3.BACK)
	roll.set("degrees_per_second", -220.0)
	roll.position = Vector3(0, 0.75, 0)
	add(r, roll, "Roll")
	var ball := model("spiky_ball", 1.5, Vector3(0, -0.75 + 0.0, 0))
	ball.position = Vector3.ZERO
	roll.add_child(ball)
	var hz := Area3D.new()
	hz.set_script(load("res://Scripts/Traps/Hazard.gd"))
	hz.position = Vector3(0, 0.75, 0)
	add(r, hz, "Hazard")
	add(hz, sphere_shape(0.7), "CollisionShape3D")
	save_scene(r, "res://Scenes/Prefabs/RollingBall.tscn")

func build_moving_platform(path: String, cols: Array):
	var b := AnimatableBody3D.new()
	b.name = "MovingPlatform"
	b.sync_to_physics = true
	b.set_script(load("res://Scripts/Traps/Mover.gd"))
	var mi := MeshInstance3D.new()
	mi.mesh = planks_mesh(3.0, 3.0, cols, 0.75, 0.06, 0.5)
	add(b, mi, "Mesh")
	add(b, box_shape(Vector3(3.2, 0.5, 3.0), Vector3(0, -0.25, 0)), "CollisionShape3D")
	save_scene(b, path)

func build_torch():
	var r := Node3D.new()
	r.name = "Torch"
	add(r, model("torch", 1.9), "TorchModel")
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.6
	l.omni_range = 7.0
	l.position = Vector3(0, 2.2, 0)
	add(r, l, "Light")
	var f := sparkles(Color(1.0, 0.6, 0.15), 12)
	f.emission_sphere_radius = 0.12
	f.gravity = Vector3(0, 2.5, 0)
	f.lifetime = 0.7
	f.position = Vector3(0, 1.95, 0)
	f.scale_amount_min = 1.5
	f.scale_amount_max = 2.2
	add(r, f, "Flame")
	save_scene(r, "res://Scenes/Prefabs/Torch.tscn")

# ============================================================ UI

func label_settings(size: int, color := Color.WHITE, outline := 10) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font_bold
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = Color(0.25, 0.11, 0.05)
	ls.shadow_size = 4
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(2, 3)
	return ls

func mk_label(text: String, ls: LabelSettings, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = ls
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func build_hud():
	var ui := Control.new()
	ui.name = "GameUI"
	ui.set_script(load("res://Scripts/GameUI.gd"))
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := HBoxContainer.new()
	bar.position = Vector2(26, 18)
	bar.add_theme_constant_override("separation", 12)
	add(ui, bar, "TopBar")
	var gem := Control.new()
	gem.set_script(load("res://Scripts/UI/GemIcon.gd"))
	gem.custom_minimum_size = Vector2(40, 48)
	add(bar, gem, "GemIcon")
	add(bar, mk_label("0 / 0", label_settings(40, Color(1, 0.95, 0.8))), "CoinsLabel")
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(26, 0)
	add(bar, sp, "Spacer")
	var hearts := Control.new()
	hearts.set_script(load("res://Scripts/UI/HeartBar.gd"))
	hearts.custom_minimum_size = Vector2(130, 40)
	hearts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add(bar, hearts, "Hearts")
	var tl := mk_label("00:00", label_settings(34, Color(1, 0.95, 0.8)), HORIZONTAL_ALIGNMENT_RIGHT)
	tl.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tl.offset_left = -220
	tl.offset_right = -26
	tl.offset_top = 20
	add(ui, tl, "TimeLabel")
	var banner := VBoxContainer.new()
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -560
	banner.offset_right = 560
	banner.offset_top = 120
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add(ui, banner, "Banner")
	add(banner, mk_label("ด่าน", label_settings(72, Color(1.0, 0.82, 0.35), 16), HORIZONTAL_ALIGNMENT_CENTER), "Title")
	add(banner, mk_label("", label_settings(32, Color(1, 0.96, 0.88)), HORIZONTAL_ALIGNMENT_CENTER), "Subtitle")
	var toast := mk_label("", label_settings(38, Color(1, 1, 1)), HORIZONTAL_ALIGNMENT_CENTER)
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.offset_left = -560
	toast.offset_right = 560
	toast.offset_top = 90
	toast.offset_bottom = 150
	add(ui, toast, "Toast")
	var help := mk_label("WASD / ลูกศร = เดิน    Space = กระโดด (กดซ้ำกลางอากาศ = ตีลังกา)    F = โจมตี    K = เตะ    Shift = กลิ้งหลบ    เมาส์ = หมุนกล้อง    Esc = ปลดเมาส์", label_settings(20, Color(1, 1, 1, 0.9), 6), HORIZONTAL_ALIGNMENT_CENTER)
	help.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	help.offset_left = -640
	help.offset_right = 640
	help.offset_top = -44
	help.offset_bottom = -12
	add(ui, help, "Help")
	save_scene(ui, "res://Scenes/UI/HUD.tscn")

func ui_theme() -> Theme:
	var th := Theme.new()
	th.default_font = font_semi
	th.default_font_size = 26
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.93, 0.5, 0.18)
	normal.set_corner_radius_all(14)
	normal.border_color = Color(0.45, 0.2, 0.07)
	normal.set_border_width_all(4)
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	normal.content_margin_left = 24
	normal.content_margin_right = 24
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(1.0, 0.65, 0.25)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.78, 0.38, 0.12)
	for st in ["normal", "focus"]:
		th.set_stylebox(st, "Button", normal if st == "normal" else hover)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_color("font_color", "Button", Color(1, 0.98, 0.92))
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_font_size("font_size", "Button", 32)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.25, 0.13, 0.07, 0.78)
	panel.set_corner_radius_all(22)
	panel.border_color = Color(1.0, 0.75, 0.4, 0.8)
	panel.set_border_width_all(3)
	panel.content_margin_left = 36
	panel.content_margin_right = 36
	panel.content_margin_top = 28
	panel.content_margin_bottom = 28
	th.set_stylebox("panel", "PanelContainer", panel)
	return th

# ============================================================ environments

func desert_env() -> Environment:
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.28, 0.55, 0.92)
	sm.sky_horizon_color = Color(0.98, 0.8, 0.58)
	sm.ground_horizon_color = Color(0.95, 0.78, 0.55)
	sm.ground_bottom_color = Color(0.75, 0.55, 0.35)
	sm.sun_angle_max = 20
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.62, 0.6, 0.7)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 0.9
	e.glow_enabled = true
	e.glow_intensity = 0.3
	e.glow_bloom = 0.0
	e.fog_enabled = true
	e.fog_light_color = Color(0.95, 0.78, 0.6)
	e.fog_density = 0.0022
	e.fog_sky_affect = 0.25
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.12
	e.adjustment_contrast = 1.05
	return e

func lava_env() -> Environment:
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.09, 0.05, 0.18)
	sm.sky_horizon_color = Color(0.95, 0.38, 0.18)
	sm.ground_horizon_color = Color(0.6, 0.18, 0.08)
	sm.ground_bottom_color = Color(0.12, 0.04, 0.03)
	sm.sun_angle_max = 30
	sm.sun_curve = 0.1
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.38, 0.5)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.7
	e.glow_bloom = 0.05
	e.glow_hdr_threshold = 0.9
	e.fog_enabled = true
	e.fog_light_color = Color(0.35, 0.14, 0.14)
	e.fog_density = 0.0045
	e.fog_sky_affect = 0.4
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.15
	return e

func add_env(root: Node3D, env: Environment, sun_rot: Vector3, sun_col: Color, sun_energy: float):
	var holder := Node3D.new()
	add(root, holder, "Environment")
	var we := WorldEnvironment.new()
	we.environment = env
	add(holder, we, "WorldEnvironment")
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_rot
	sun.light_color = sun_col
	sun.light_energy = sun_energy
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70
	add(holder, sun, "Sun")

# ============================================================ level building blocks

var L: Node3D          # level root being built
var groups := {}

func grp(name: String) -> Node3D:
	if not groups.has(name):
		var n := Node3D.new()
		n.name = name
		L.add_child(n)
		groups[name] = n
	return groups[name]

func static_mesh(parent: Node3D, name: String, mesh: ArrayMesh, pos: Vector3, convex := true) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	parent.add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add(body, mi, "Mesh")
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_convex_shape(true, true) if convex else mesh.create_trimesh_shape()
	add(body, cs, "CollisionShape3D")
	return body

var palette := {}

func mesa(name: String, pos: Vector3, r: float, sides := 8, depth := 6.0):
	var rings: Array
	if palette.style == "desert":
		rings = [[0.0, 1.0], [-0.35, 1.0], [-1.0, 0.97], [-1.9, 0.88], [-2.9, 0.72], [-depth, 0.25]]
	else:
		rings = [[0.0, 1.0], [-0.3, 1.0], [-1.2, 1.0], [-3.5, 1.02], [-depth, 1.05]]
	var m := island_mesh(r, sides, rings, palette.bands, palette.top, 0.06)
	static_mesh(grp("Platforms"), name, m, pos)

func bridge(name: String, from: Vector3, to: Vector3, width: float):
	var dir := to - from
	var blen := Vector2(dir.x, dir.z).length()
	var m := planks_mesh(blen, width, palette.planks, 0.7 if palette.style == "desert" else 1.0, 0.07 if palette.style == "desert" else 0.05)
	var body := StaticBody3D.new()
	body.name = name
	body.position = (from + to) / 2.0
	body.rotation.y = atan2(-dir.x, -dir.z)
	grp("Platforms").add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = m
	add(body, mi, "Mesh")
	add(body, box_shape(Vector3(width, 0.45, blen), Vector3(0, -0.225, 0)), "CollisionShape3D")

func inst(path: String, parent: Node3D, pos: Vector3, rot_y := 0.0, props := {}) -> Node3D:
	var n: Node3D = load(path).instantiate()
	n.position = pos
	n.rotation_degrees.y = rot_y
	for k in props:
		n.set(k, props[k])
	parent.add_child(n)
	return n

func deco(file: String, h: float, pos: Vector3, rot_y := -1.0):
	var m := model(file, h * rng.randf_range(0.9, 1.1), pos, rot_y if rot_y >= 0 else rng.randf_range(0, 360))
	grp("Decorations").add_child(m)

func label3d(text: String, pos: Vector3, size := 72, rot_y := 0.0, color := Color(1, 0.92, 0.7)):
	var l := Label3D.new()
	l.text = text
	l.font = font_bold
	l.font_size = size
	l.outline_size = 18
	l.modulate = color
	l.outline_modulate = Color(0.28, 0.12, 0.05)
	l.position = pos
	l.rotation_degrees.y = rot_y
	l.pixel_size = 0.008
	l.name = "Sign%d" % (grp("Signs").get_child_count() + 1)
	grp("Signs").add_child(l)

func gem(pos: Vector3):
	var g := inst(palette.gem, grp("Gems"), pos)
	g.name = "Gem%d" % grp("Gems").get_child_count()

func level_base(name: String, title: String, subtitle: String, spawn: Vector3):
	L = Node3D.new()
	L.name = name
	L.set_script(load("res://Scripts/Level.gd"))
	groups = {}
	var sp := Marker3D.new()
	sp.position = spawn
	add(L, sp, "SpawnPosition")
	inst("res://Scenes/player.tscn", L, spawn)
	var layer := CanvasLayer.new()
	add(L, layer, "UserInterface")
	inst_ui("res://Scenes/UI/HUD.tscn", layer, {"level_title": title, "level_subtitle": subtitle})

func inst_ui(path: String, parent: Node, props: Dictionary):
	var n: Node = load(path).instantiate()
	for k in props:
		n.set(k, props[k])
	parent.add_child(n)

func dead_zone(center: Vector3, size: Vector3):
	var a := Area3D.new()
	a.set_script(load("res://Scripts/DeadZone.gd"))
	a.position = center
	add(L, a, "DeadZone")
	add(a, box_shape(size), "CollisionShape3D")

# ============================================================ LEVEL 1 : Sun-Baked Canyon

func build_level1():
	rng.seed = 101
	palette = {
		"style": "desert",
		"top": Color(0.9, 0.7, 0.42),
		"bands": [Color(0.88, 0.55, 0.28), Color(0.76, 0.38, 0.2), Color(0.86, 0.52, 0.28), Color(0.64, 0.3, 0.17), Color(0.52, 0.25, 0.15)],
		"planks": [Color(0.62, 0.38, 0.2), Color(0.7, 0.45, 0.24), Color(0.58, 0.34, 0.18)],
		"gem": "res://Scenes/Prefabs/GemWater.tscn",
	}
	level_base("Level1", "ด่าน 1 : หุบเขาทะเลทราย", "เก็บคริสตัลน้ำให้ครบ 8 ชิ้น แล้วไปที่ประตู", Vector3(0, 1, 3))
	add_env(L, desert_env(), Vector3(-48, -35, 0), Color(1.0, 0.93, 0.8), 1.0)

	# --- start area
	mesa("Start", Vector3(0, 0, 0), 7, 9, 8)
	label3d("Oasis Quest", Vector3(0, 4.6, -7), 110)
	label3d("ทะเลทรายแห้งแล้ง... ช่วยนักศึกษาตามหาคริสตัลน้ำ!", Vector3(0, 3.5, -7), 42, 0, Color(1, 1, 1))
	gem(Vector3(-3, 1.1, -3.5))
	deco("palm_tree", 4.2, Vector3(-4.2, 0, 3.0))
	deco("palm_tree", 3.6, Vector3(4.8, 0, 3.5))
	deco("cactus", 1.9, Vector3(5.0, 0, -2.0))
	deco("cactus_flowers", 1.2, Vector3(-5.0, 0, -1.0))
	deco("cactus_flowers", 1.0, Vector3(3.2, 0, -5.0))
	deco("rock", 1.6, Vector3(-5.2, 0, -4.2))
	deco("skull", 0.5, Vector3(2.4, 0, 5.2))
	deco("fish_bone", 0.25, Vector3(-1.8, 0.02, 5.4))

	mesa("Step1", Vector3(0, 0.8, -12), 3.2, 7, 5)
	gem(Vector3(0, 2.0, -12))
	deco("cactus", 1.6, Vector3(1.6, 0.8, -13.2))
	mesa("Step2", Vector3(6, 1.6, -19), 3.0, 7, 5)
	deco("rock", 1.2, Vector3(7.6, 1.6, -18.0))

	# --- spike bridge
	bridge("SpikeBridge", Vector3(6, 1.6, -21.6), Vector3(6, 1.6, -38.6), 4.0)
	var ph := 0.0
	for z in [-26.0, -30.0, -34.0]:
		for x in [5.0, 7.0]:
			inst("res://Scenes/Prefabs/PopUpSpikes.tscn", grp("Traps"), Vector3(x, 1.6, z), 0, {"phase": ph})
		ph += 0.33
	gem(Vector3(6, 2.6, -32))
	label3d("ระวังหนามโผล่!", Vector3(6, 4.2, -22), 48, 0, Color(1, 0.75, 0.6))

	# --- checkpoint mesa + moving rafts
	mesa("Checkpoint1Mesa", Vector3(6, 1.6, -44), 5, 9, 7)
	inst("res://Scenes/Prefabs/Checkpoint.tscn", grp("Checkpoints"), Vector3(8.2, 1.6, -45.5), 0)
	deco("palm_tree", 3.8, Vector3(3.0, 1.6, -46.5))
	deco("rock_large2", 2.4, Vector3(9.2, 1.6, -40.8))
	inst("res://Scenes/Prefabs/MovingPlatformWood.tscn", grp("MovingPlatforms"), Vector3(-0.6, 1.6, -44), 0, {"offset": Vector3(-8, 0, 0), "duration": 4.0})
	gem(Vector3(-5.5, 3.3, -44))
	mesa("RaftLanding", Vector3(-15.5, 2.4, -44), 3.5, 8, 6)
	deco("cactus", 1.7, Vector3(-16.5, 2.4, -46.2))
	deco("large_bone", 1.4, Vector3(-14.5, 2.4, -41.5))

	# --- pendulum bridge
	bridge("PendulumBridge", Vector3(-18.6, 2.4, -44), Vector3(-37.4, 2.4, -44), 2.6)
	var pp := 0.0
	for x in [-23.0, -28.0, -33.0]:
		var p := inst("res://Scenes/Prefabs/Pendulum.tscn", grp("Traps"), Vector3(x, 2.4, -44), 0)
		p.set("phase", pp)
		pp += 0.3
	gem(Vector3(-28, 3.4, -44))

	# --- spinner mesa
	mesa("SpinnerMesa", Vector3(-42.5, 2.4, -44), 5, 10, 7)
	inst("res://Scenes/Prefabs/Spinner.tscn", grp("Traps"), Vector3(-42.5, 2.4, -44), 0)
	gem(Vector3(-42.5, 3.3, -40.6))
	deco("rock", 1.8, Vector3(-46.8, 2.4, -46.5))

	# --- stairs up to the oasis
	mesa("Stair1", Vector3(-42.5, 3.4, -35.4), 2.3, 7, 5)
	inst("res://Scenes/Prefabs/Checkpoint.tscn", grp("Checkpoints"), Vector3(-42.5, 3.4, -35.4), 0)
	mesa("Stair2", Vector3(-38.0, 4.4, -31.0), 2.1, 7, 5)
	mesa("Stair3", Vector3(-42.5, 5.4, -26.5), 2.3, 7, 5)
	mesa("HighPillar", Vector3(-48.5, 7.0, -26.5), 1.4, 6, 9)
	gem(Vector3(-48.5, 8.2, -26.5))
	label3d("ตีลังกา! (กระโดด 2 ครั้ง)", Vector3(-48.5, 9.6, -26.5), 40, 90, Color(0.8, 0.95, 1))

	# --- oasis + exit door
	mesa("OasisMesa", Vector3(-42.5, 6.2, -16.5), 5.8, 11, 8)
	inst("res://Scenes/Prefabs/Door.tscn", grp("Exit"), Vector3(-42.5, 6.2, -12.4), 180)
	inst("res://Scenes/Prefabs/RollingBall.tscn", grp("Traps"), Vector3(-45.3, 6.2, -17.5), 0, {"offset": Vector3(5.6, 0, 0), "duration": 2.6})
	gem(Vector3(-42.5, 7.3, -17.5))
	var pool := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 1.7
	pm.bottom_radius = 1.7
	pm.height = 0.1
	pm.radial_segments = 8
	var wm := ShaderMaterial.new()
	wm.shader = load("res://Assets/Shaders/water.gdshader")
	pm.material = wm
	pool.mesh = pm
	pool.position = Vector3(-38.6, 6.22, -14.2)
	grp("Decorations").add_child(pool)
	pool.name = "OasisPool"
	deco("palm_tree", 4.4, Vector3(-37.0, 6.2, -12.4))
	deco("palm_tree", 3.8, Vector3(-46.5, 6.2, -13.6))
	deco("palm_tree", 3.4, Vector3(-37.4, 6.2, -17.6))
	deco("cactus_flowers", 1.2, Vector3(-46.8, 6.2, -18.5))
	deco("crystal", 2.6, Vector3(-47.0, 6.2, -16.0))
	deco("rock", 1.0, Vector3(-40.2, 6.2, -12.8))

	# --- background: dunes, buttes, rocks, clouds
	var dunes := MeshInstance3D.new()
	dunes.mesh = dunes_mesh(520, 52, 4.0, [Color(0.8, 0.52, 0.3), Color(0.93, 0.74, 0.48)])
	dunes.position = Vector3(-20, -16, -25)
	dunes.name = "SandDunes"
	grp("Background").add_child(dunes)
	rng.seed = 55
	for i in 14:
		var ang := TAU * i / 14 + rng.randf_range(-0.15, 0.15)
		var dist := rng.randf_range(75, 120)
		var h := rng.randf_range(14, 38)
		var r := rng.randf_range(7, 15)
		var rings := [[0.0, 1.0], [-1.0, 1.0], [-h * 0.3, 1.05], [-h * 0.6, 1.12], [-h - 16, 1.3]]
		var bm := MeshInstance3D.new()
		bm.mesh = island_mesh(r, rng.randi_range(7, 10), rings, palette.bands, palette.top.darkened(0.05), 0.1)
		bm.position = Vector3(-20 + cos(ang) * dist, -16 + h, -25 + sin(ang) * dist)
		bm.name = "Butte%d" % i
		grp("Background").add_child(bm)
	for i in 10:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(35, 60)
		var m := model("rock_large" if i % 2 == 0 else "rock_large2", rng.randf_range(6, 12), Vector3(-20 + cos(ang) * dist, -17, -25 + sin(ang) * dist), rng.randf_range(0, 360))
		grp("Background").add_child(m)
	for i in 8:
		var c := model("res://Assets/Models/cloud.glb", rng.randf_range(3, 6), Vector3(rng.randf_range(-90, 50), rng.randf_range(22, 34), rng.randf_range(-110, 40)), rng.randf_range(0, 360))
		c.scale *= Vector3(2.2, 1, 2.2)
		grp("Background").add_child(c)

	dead_zone(Vector3(-20, -12, -25), Vector3(300, 4, 300))
	save_scene(L, "res://Scenes/Levels/Level1.tscn")

# ============================================================ LEVEL 2 : Lava Ruins

func build_level2():
	rng.seed = 202
	palette = {
		"style": "basalt",
		"top": Color(0.42, 0.38, 0.4),
		"bands": [Color(0.3, 0.26, 0.28), Color(0.22, 0.19, 0.21), Color(0.18, 0.15, 0.17), Color(0.35, 0.12, 0.06)],
		"planks": [Color(0.45, 0.42, 0.44), Color(0.38, 0.35, 0.38), Color(0.5, 0.46, 0.46)],
		"gem": "res://Scenes/Prefabs/GemFire.tscn",
	}
	level_base("Level2", "ด่าน 2 : ซากวิหารลาวา", "เก็บคริสตัลไฟ 8 ชิ้น หนีออกจากภูเขาไฟ!", Vector3(0, 1, 3))
	add_env(L, lava_env(), Vector3(-18, -150, 0), Color(1.0, 0.55, 0.35), 0.9)

	mesa("Start", Vector3(0, 0, 0), 6, 6, 14)
	label3d("ซากวิหารลาวา", Vector3(0, 4.4, -6.5), 100, 0, Color(1, 0.7, 0.4))
	label3d("ระวังตกลาวา!", Vector3(0, 3.3, -6.5), 44, 0, Color(1, 1, 1))
	gem(Vector3(3, 1.1, -2.5))
	mesa("TempleRock", Vector3(-11, -0.5, 0), 3.4, 6, 14)
	deco("temple", 6.0, Vector3(-11, -0.5, 0), 90)
	inst("res://Scenes/Prefabs/Torch.tscn", grp("Torches"), Vector3(-8.6, -0.5, 2.2))
	for p in [Vector3(-3.6, 0, -3.6), Vector3(3.6, 0, -3.6)]:
		inst("res://Scenes/Prefabs/Torch.tscn", grp("Torches"), p)
	deco("skull", 0.5, Vector3(-3.5, 0, 1.0))
	deco("tree_lava", 3.2, Vector3(4.2, 0, 1.8))

	mesa("Stone1", Vector3(0, 0, -9.5), 1.8, 6, 12)
	mesa("Stone2", Vector3(3, 0.6, -14), 1.8, 6, 12)
	gem(Vector3(3, 1.8, -14))
	mesa("Stone3", Vector3(0, 1.2, -18.5), 1.8, 6, 12)
	inst("res://Scenes/Prefabs/MovingPlatformStone.tscn", grp("MovingPlatforms"), Vector3(0, 1.2, -23.2), 0, {"offset": Vector3(0, 0, -5.8), "duration": 3.6})

	# --- spinner hall
	mesa("SpinnerHex", Vector3(0, 1.2, -36), 5, 6, 14)
	inst("res://Scenes/Prefabs/Spinner.tscn", grp("Traps"), Vector3(0, 1.2, -36), 0, {"degrees_per_second": 85.0})
	gem(Vector3(3.3, 2.1, -36))
	gem(Vector3(-3.3, 2.1, -36))
	inst("res://Scenes/Prefabs/Checkpoint.tscn", grp("Checkpoints"), Vector3(0, 1.2, -18.5), 0)
	for p in [Vector3(-4.2, 1.2, -38.5), Vector3(4.2, 1.2, -38.5)]:
		inst("res://Scenes/Prefabs/Torch.tscn", grp("Torches"), p)

	# --- spike corridor
	bridge("SpikeCorridor", Vector3(0, 1.2, -40.6), Vector3(0, 1.2, -59.6), 4.0)
	var ph := 0.0
	for z in [-44.0, -47.5, -51.0, -54.5]:
		for x in [-1.0, 1.0]:
			inst("res://Scenes/Prefabs/PopUpSpikes.tscn", grp("Traps"), Vector3(x, 1.2, z), 0, {"phase": ph, "down_time": 1.4})
		ph += 0.25
	gem(Vector3(0, 2.2, -49.25))

	mesa("Hex6", Vector3(0, 1.2, -64), 4.5, 6, 14)
	inst("res://Scenes/Prefabs/Checkpoint.tscn", grp("Checkpoints"), Vector3(-1.5, 1.2, -65.5), 0)
	inst("res://Scenes/Prefabs/Torch.tscn", grp("Torches"), Vector3(2.6, 1.2, -61.5))
	deco("column", 3.0, Vector3(-3.0, 1.2, -61.8), 0)

	# --- pendulum bridge
	bridge("PendulumBridge", Vector3(4.4, 1.2, -64), Vector3(22.6, 1.2, -64), 2.6)
	var pp := 0.0
	for x in [9.0, 13.5, 18.0]:
		var p := inst("res://Scenes/Prefabs/Pendulum.tscn", grp("Traps"), Vector3(x, 1.2, -64), 0)
		p.set("phase", pp)
		p.set("period", 2.2)
		pp += 0.45
	gem(Vector3(13.5, 2.2, -64))

	mesa("Hex7", Vector3(27, 1.2, -64), 4.5, 6, 14)
	inst("res://Scenes/Prefabs/Torch.tscn", grp("Torches"), Vector3(29.8, 1.2, -61.8))
	inst("res://Scenes/Prefabs/MovingPlatformStone.tscn", grp("MovingPlatforms"), Vector3(27, 1.2, -71), 0, {"offset": Vector3(0, 4.0, 0), "duration": 4.0})
	label3d("ลิฟต์หิน", Vector3(30.5, 3.4, -69), 40, -90, Color(1, 0.9, 0.7))

	mesa("Hex8", Vector3(27, 5.2, -77.5), 3, 6, 18)
	mesa("FirePillar", Vector3(33.5, 6.8, -79), 1.25, 6, 20)
	gem(Vector3(33.5, 8.0, -79))

	# --- exit
	mesa("ExitHex", Vector3(27, 5.8, -87.5), 5, 6, 20)
	inst("res://Scenes/Prefabs/Door.tscn", grp("Exit"), Vector3(27, 5.8, -91.4), 0)
	inst("res://Scenes/Prefabs/RollingBall.tscn", grp("Traps"), Vector3(24.2, 5.8, -86.5), 0, {"offset": Vector3(5.6, 0, 0), "duration": 2.2})
	gem(Vector3(27, 6.9, -86.5))
	for p in [Vector3(23.4, 5.8, -91.0), Vector3(30.6, 5.8, -91.0)]:
		inst("res://Scenes/Prefabs/Torch.tscn", grp("Torches"), p)
	deco("column", 3.4, Vector3(22.8, 5.8, -88.8), 0)
	deco("column", 3.4, Vector3(31.2, 5.8, -88.8), 0)
	deco("skull", 0.5, Vector3(30.5, 5.8, -84.5))
	deco("tree_lava", 3.0, Vector3(23.0, 5.8, -84.5))

	# --- lava sea, background columns, volcano, embers
	var lava := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(520, 520)
	pm.subdivide_width = 70
	pm.subdivide_depth = 70
	var lm := ShaderMaterial.new()
	lm.shader = load("res://Assets/Shaders/lava.gdshader")
	pm.material = lm
	lava.mesh = pm
	lava.position = Vector3(14, -4, -45)
	lava.name = "LavaSea"
	grp("Background").add_child(lava)
	rng.seed = 77
	for i in 40:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(30, 110)
		var pos := Vector3(14 + cos(ang) * dist, rng.randf_range(-1, 14), -45 + sin(ang) * dist)
		var r := rng.randf_range(1.5, 5)
		var bm := MeshInstance3D.new()
		bm.mesh = island_mesh(r, 6, [[0.0, 1.0], [-0.4, 1.0], [-pos.y - 9, 1.05]], palette.bands, palette.top, 0.05)
		bm.position = pos
		bm.name = "BasaltColumn%d" % i
		grp("Background").add_child(bm)
	var volcano := MeshInstance3D.new()
	volcano.mesh = cone_mesh(85, 62, 12, Color(0.2, 0.13, 0.14), Color(1.0, 0.45, 0.1), 0.18)
	volcano.position = Vector3(40, -6, -360)
	volcano.name = "Volcano"
	grp("Background").add_child(volcano)
	var embers := sparkles(Color(1.0, 0.5, 0.15), 160)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	embers.emission_box_extents = Vector3(45, 1, 55)
	embers.lifetime = 7
	embers.gravity = Vector3(0.3, 1.2, 0)
	embers.position = Vector3(14, -3, -45)
	embers.scale_amount_min = 1.2
	embers.scale_amount_max = 2.0
	embers.visibility_aabb = AABB(Vector3(-60, -5, -70), Vector3(120, 40, 140))
	embers.name = "Embers"
	grp("Background").add_child(embers)

	dead_zone(Vector3(14, -5, -45), Vector3(300, 4, 300))
	save_scene(L, "res://Scenes/Levels/Level2.tscn")

# ============================================================ Title & Win

func build_menu(path: String, is_win: bool):
	rng.seed = 303 if is_win else 404
	palette = {"style": "desert", "top": Color(0.9, 0.7, 0.42),
		"bands": [Color(0.88, 0.55, 0.28), Color(0.76, 0.38, 0.2), Color(0.86, 0.52, 0.28), Color(0.64, 0.3, 0.17)],
		"planks": [], "gem": ""}
	L = Node3D.new()
	L.name = "Win" if is_win else "Title"
	groups = {}
	add_env(L, desert_env(), Vector3(-35, -60, 0), Color(1.0, 0.9, 0.75), 1.0)
	mesa("Island", Vector3.ZERO, 6, 10, 8)
	var hero := Node3D.new()
	hero.name = "Player"
	hero.rotation_degrees.y = 15
	L.add_child(hero)
	hero_with_anims(hero)
	deco("palm_tree", 4.4, Vector3(-3.2, 0, -2.2))
	deco("palm_tree", 3.6, Vector3(3.4, 0, -3.0))
	deco("cactus_flowers", 1.0, Vector3(-1.6, 0, 1.2))
	deco("cactus", 1.8, Vector3(-2.6, 0, -1.6))
	for i in 5:
		var g := model("gem_blue" if i % 2 == 0 else "gem_pink", 0.7, Vector3(cos(i * 0.7 + 1.4) * 2.0 - 0.3, 1.4 + 0.35 * sin(i * 2.0), -sin(i * 0.7 + 1.4) * 1.4 - 0.6))
		grp("Decorations").add_child(g)
	if is_win:
		var pool := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 1.6
		pm.bottom_radius = 1.6
		pm.height = 0.1
		pm.radial_segments = 8
		var wm := ShaderMaterial.new()
		wm.shader = load("res://Assets/Shaders/water.gdshader")
		pm.material = wm
		pool.mesh = pm
		pool.position = Vector3(1.6, 0.03, -1.0)
		pool.name = "OasisPool"
		grp("Decorations").add_child(pool)
	var dunes := MeshInstance3D.new()
	dunes.mesh = dunes_mesh(400, 40, 4.0, [Color(0.8, 0.52, 0.3), Color(0.93, 0.74, 0.48)])
	dunes.position = Vector3(0, -14, 0)
	dunes.name = "SandDunes"
	grp("Background").add_child(dunes)
	for i in 8:
		var ang := TAU * i / 8 + 0.3
		var h := rng.randf_range(16, 32)
		var bm := MeshInstance3D.new()
		bm.mesh = island_mesh(rng.randf_range(7, 12), 8, [[0.0, 1.0], [-1.0, 1.0], [-h * 0.4, 1.06], [-h - 14, 1.25]], palette.bands, palette.top, 0.1)
		bm.position = Vector3(cos(ang) * 80, -14 + h, sin(ang) * 80)
		bm.name = "Butte%d" % i
		grp("Background").add_child(bm)
	var rig := Node3D.new()
	rig.name = "CameraRig"
	rig.set_script(load("res://Scripts/Showcase.gd"))
	rig.set("animation_name", "Victory" if is_win else "Idle")
	L.add_child(rig)
	var cam := Camera3D.new()
	var cpos := Vector3(1.9, 1.75, 4.6)
	cam.transform = Transform3D(Basis.looking_at(Vector3(1.9, 1.05, 0) - cpos), cpos)
	cam.fov = 55
	add(rig, cam, "Camera3D")

	var layer := CanvasLayer.new()
	add(L, layer, "UI")
	var menu := Control.new()
	menu.name = "Menu"
	menu.set_script(load("res://Scripts/Menu.gd"))
	menu.set("is_win_screen", is_win)
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.theme = ui_theme()
	add(layer, menu)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -600
	panel.offset_right = -60
	panel.offset_top = -270
	panel.offset_bottom = 270
	add(menu, panel, "Panel")
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	add(panel, vb, "VBox")
	if is_win:
		add(vb, mk_label("ยินดีด้วย!", label_settings(84, Color(1, 0.82, 0.35), 16), HORIZONTAL_ALIGNMENT_CENTER), "Title")
		add(vb, mk_label("นักศึกษาเก็บคริสตัลครบ โอเอซิสกลับมามีน้ำอีกครั้ง", label_settings(26, Color(1, 0.97, 0.9), 6), HORIZONTAL_ALIGNMENT_CENTER), "Story")
		(vb.get_node("Story") as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add(vb, mk_label("เวลาที่ใช้: 00:00", label_settings(40, Color(0.75, 1, 0.8), 10), HORIZONTAL_ALIGNMENT_CENTER), "TimeLabel")
		var b1 := Button.new()
		b1.text = "เล่นอีกครั้ง"
		add(vb, b1, "StartButton")
		var b2 := Button.new()
		b2.text = "กลับหน้าแรก"
		add(vb, b2, "TitleButton")
	else:
		add(vb, mk_label("Oasis Quest", label_settings(96, Color(0.55, 0.92, 0.45), 18), HORIZONTAL_ALIGNMENT_CENTER), "Title")
		add(vb, mk_label("ภารกิจนักศึกษาตามหาโอเอซิส", label_settings(30, Color(1, 0.85, 0.5), 8), HORIZONTAL_ALIGNMENT_CENTER), "Subtitle")
		var how := mk_label("• เก็บคริสตัลให้ครบ แล้วเข้าประตูไปด่านต่อไป (หัวใจ 3 ดวง)\n• WASD เดิน · Space กระโดด · กดซ้ำกลางอากาศ = ตีลังกา\n• F โจมตี · K เตะ · Shift กลิ้งหลบกับดัก · เมาส์หมุนกล้อง", label_settings(22, Color(1, 0.97, 0.9), 5))
		how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		add(vb, how, "HowTo")
		var b := Button.new()
		b.text = "เริ่มเกม"
		add(vb, b, "StartButton")
		var demo := Button.new()
		demo.text = "ดูท่าทางตัวละครทั้งหมด"
		add(vb, demo, "DemoButton")
		add(vb, mk_label("Lab 6 ตัวละคร 3D · Blender + Mixamo + Open Animation Libraries · Godot 4.7", label_settings(16, Color(1, 1, 1, 0.75), 4), HORIZONTAL_ALIGNMENT_CENTER), "Credits")
		(vb.get_node("Credits") as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_scene(L, path)

# ============================================================ main

func _initialize():
	vc_mat = StandardMaterial3D.new()
	vc_mat.vertex_color_use_as_albedo = true
	vc_mat.roughness = 0.95
	DirAccess.make_dir_recursive_absolute("res://Assets/Materials")
	ResourceSaver.save(vc_mat, "res://Assets/Materials/lowpoly_vertex_color.tres")
	vc_mat = load_fresh_res("res://Assets/Materials/lowpoly_vertex_color.tres")
	font_bold = load("res://Assets/Fonts/Kanit-Bold.ttf")
	font_semi = load("res://Assets/Fonts/Kanit-SemiBold.ttf")
	rng.seed = 1

	build_anim_library()
	build_player()
	build_gem("res://Scenes/Prefabs/GemWater.tscn", "gem_blue", Color(0.5, 0.85, 1.0))
	build_gem("res://Scenes/Prefabs/GemFire.tscn", "gem_pink", Color(1.0, 0.55, 0.7))
	build_checkpoint()
	build_door()
	build_spikes()
	build_pendulum()
	build_spinner()
	build_roller()
	build_moving_platform("res://Scenes/Prefabs/MovingPlatformWood.tscn", [Color(0.66, 0.42, 0.22), Color(0.74, 0.5, 0.27), Color(0.6, 0.37, 0.2)])
	build_moving_platform("res://Scenes/Prefabs/MovingPlatformStone.tscn", [Color(0.5, 0.46, 0.46), Color(0.42, 0.38, 0.4), Color(0.9, 0.42, 0.12)])
	build_torch()
	build_hud()
	build_level1()
	build_level2()
	build_menu("res://Scenes/UI/Title.tscn", false)
	build_menu("res://Scenes/UI/Win.tscn", true)
	quit()
