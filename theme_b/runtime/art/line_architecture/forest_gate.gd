@tool
extends Node3D
## All geometry lies around local XZ; local +Y is the absorption direction.
var _sparks: MultiMesh
var _clock := 0.0
const SPARK_COUNT := 72
const TRAIL_COUNT := 4

func _ready() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in range(3):
		for step in range(80):
			var a := float(step) / 80.0 * TAU
			var b := float(step + 1) / 80.0 * TAU
			_tube(surface, _vine(a, strand), _vine(b, strand), 0.009 + strand * 0.002,
				Color("526b45").lerp(Color("b6a66a"), 0.5 + 0.5 * sin(a * 2.0 + strand)))
	for i in range(34):
		var a := float(i) / 34.0 * TAU
		var base := _vine(a, i % 3)
		var radial := Vector3(cos(a), 0, sin(a))
		var tangent := Vector3(-sin(a), 0, cos(a))
		var direction := (tangent * 0.8 + radial * (0.65 if i % 2 == 0 else -0.55)).normalized()
		var length_leaf := 0.10 + 0.035 * (0.5 + 0.5 * sin(i * 7.3))
		var tip := base + direction * length_leaf
		var across := Vector3(-direction.z, 0, direction.x) * length_leaf * 0.25
		var middle := base.lerp(tip, 0.45)
		var ridge := middle + Vector3.UP * 0.018
		var color := Color("427560").lerp(Color("b2bd78"), 0.5 + 0.5 * sin(i * 2.3))
		_triangle(surface, base, middle + across, ridge, color)
		_triangle(surface, middle + across, tip, ridge, color)
		_triangle(surface, tip, middle - across, ridge, color.darkened(0.28))
		_triangle(surface, middle - across, base, ridge, color.darkened(0.28))
	var foliage := MeshInstance3D.new()
	foliage.name = "WovenBranchesAndLeaves"
	foliage.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	foliage.material_override = material
	foliage.set_meta("fluorescent", true)
	add_child(foliage)
	var effects := get_node("VortexEffects") as Node3D
	var opening := MeshInstance3D.new()
	opening.name = "ForestVortex"
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.97, 0.97)
	opening.mesh = plane
	opening.position.y = 0.012
	var portal_material := ShaderMaterial.new()
	portal_material.shader = preload("res://theme_b/runtime/art/line_architecture/forest_gate.gdshader")
	opening.material_override = portal_material
	opening.set_meta("fluorescent", true)
	effects.add_child(opening)
	var fireflies := MultiMeshInstance3D.new()
	fireflies.name = "OrbitingFireflies"
	_sparks = MultiMesh.new()
	_sparks.transform_format = MultiMesh.TRANSFORM_3D
	_sparks.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.065, 0.065)
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://theme_b/runtime/art/line_architecture/firefly.gdshader")
	quad.material = glow
	_sparks.mesh = quad
	_sparks.instance_count = SPARK_COUNT * TRAIL_COUNT
	fireflies.multimesh = _sparks
	fireflies.custom_aabb = AABB(Vector3(-0.8, -0.1, -0.8), Vector3(1.6, 0.6, 1.6))
	effects.add_child(fireflies)
	_process(0.0)

func _vine(a: float, strand: int) -> Vector3:
	var phase := a * 5.0 + strand * TAU / 3.0
	var radius := 0.49 + 0.022 * sin(phase)
	return Vector3(cos(a) * radius, 0.025 + 0.018 * cos(phase), sin(a) * radius)

func _triangle(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	s.set_color(color)
	s.set_normal((b-a).cross(c-a).normalized())
	s.add_vertex(a)
	s.add_vertex(b)
	s.add_vertex(c)

func _tube(s: SurfaceTool, a: Vector3, b: Vector3, radius: float, color: Color) -> void:
	var axis := (b-a).normalized()
	var side := axis.cross(Vector3.UP).normalized()
	var up := axis.cross(side).normalized()
	for i in range(6):
		var p := (side * cos(i * TAU / 6.0) + up * sin(i * TAU / 6.0)) * radius
		var q := (side * cos((i+1) * TAU / 6.0) + up * sin((i+1) * TAU / 6.0)) * radius
		_triangle(s, a+p, b+p, b+q, color)
		_triangle(s, a+p, b+q, a+q, color)

func _process(delta: float) -> void:
	if _sparks == null:
		return
	_clock += delta
	for i in range(SPARK_COUNT):
		for trail in range(TRAIL_COUNT):
			var t := _clock - trail * 0.045
			var seed_phase := float(i) * 2.39996
			var angle := seed_phase + t * (0.3 + float(i % 5) * 0.055)
			var radius := 0.20 + float(i % 11) * 0.032 + 0.025 * sin(t + seed_phase)
			var pos := Vector3(cos(angle)*radius, 0.05 + 0.08*(0.5+0.5*sin(t*0.7+seed_phase)), sin(angle)*radius)
			var index := i * TRAIL_COUNT + trail
			_sparks.set_instance_transform(index, Transform3D(Basis.IDENTITY, pos))
			var brightness := (0.5 + 0.5 * pow(0.5 + 0.5 * sin(t*1.8+seed_phase), 2.0)) * pow(0.48, trail)
			_sparks.set_instance_custom_data(index, Color(brightness, 0, 0, 1))
