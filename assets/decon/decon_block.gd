extends StaticBody3D

## The cube mesh lives in this scene so it can be dragged in the editor.
## This script only sets the black-and-white look from the cell it sits on.

const _SKETCH := preload("res://assets/decon/decon_sketch.gdshader")
const _STYLE := preload("res://assets/decon/decon_style.gd")

var _shade := 0.54


func _ready() -> void:
	add_to_group("decon_block")
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed()
	_shade = rng.randf_range(0.46, 0.62)
	apply_from_style(_STYLE.load_default())


func apply_from_style(style) -> void:
	var mesh_node := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_node == null:
		return
	var axes := _wall_axes()
	var mat := ShaderMaterial.new()
	mat.shader = _SKETCH
	style.apply_block(mat, _shade, axes[0], axes[1])
	mesh_node.mesh = _mesh_for(float(style.roundness))
	mesh_node.material_override = mat
	mesh_node.scale = Vector3.ONE * style.visual_scale()
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _seed() -> int:
	var cell := Vector3i(Vector3(round(position.x * 2.0), round(position.y * 2.0), round(position.z * 2.0)))
	return cell.x * 73856093 ^ cell.y * 19349663 ^ cell.z * 83492791


func _wall_axes() -> Array:
	var center := Vector3(0.0, 3.0, 0.0)
	var toward := center - position
	if toward.length_squared() < 0.0001:
		toward = Vector3.UP
	# Distance to the shell. Equal distances are the corner row; prefer the floor
	# or ceiling, then the z wall, so that row is not painted as the side wall.
	var dist := Vector3(
		minf(absf(position.x - 3.0), absf(position.x + 3.0)),
		minf(absf(position.y), absf(position.y - 6.0)),
		minf(absf(position.z - 3.0), absf(position.z + 3.0))
	)
	var score := dist + Vector3(0.02, 0.0, 0.01)
	var main := 0
	var best := score.x
	if score.y < best:
		best = score.y
		main = 1
	if score.z < best:
		main = 2
	var face := Vector3.ZERO
	face[main] = signf(toward[main])
	if is_zero_approx(face[main]):
		face[main] = 1.0
	var side := Vector3.ZERO
	side[(main + 1) % 3] = 1.0
	return [face, side]


static var _sharp_box: BoxMesh
static var _rounded_boxes: Dictionary = {}


static func _mesh_for(amount: float) -> Mesh:
	if amount <= 0.001:
		if _sharp_box == null:
			_sharp_box = BoxMesh.new()
			_sharp_box.size = Vector3.ONE
		return _sharp_box
	var key := "c-%0.2f" % snappedf(amount, 0.01)
	if not _rounded_boxes.has(key):
		_rounded_boxes[key] = _make_rounded_box(snappedf(amount, 0.01) * 0.3)
	return _rounded_boxes[key]


static func _make_rounded_box(radius: float) -> ArrayMesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	box.subdivide_width = 8
	box.subdivide_height = 8
	box.subdivide_depth = 8
	var arrays := box.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		verts[i] = _round_point(verts[i], radius)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	return st.commit()


static func _round_point(point: Vector3, radius: float) -> Vector3:
	var inner := 0.5 - radius
	var ap := point.abs()
	var excess := Vector3(maxf(ap.x - inner, 0.0), maxf(ap.y - inner, 0.0), maxf(ap.z - inner, 0.0))
	var kept := Vector3(minf(ap.x, inner), minf(ap.y, inner), minf(ap.z, inner))
	var curved := kept
	var reach := excess.length()
	if reach > 0.00001:
		curved += excess / reach * radius
	return Vector3(_sgn(point.x) * curved.x, _sgn(point.y) * curved.y, _sgn(point.z) * curved.z)


static func _sgn(value: float) -> float:
	return -1.0 if value < 0.0 else 1.0
