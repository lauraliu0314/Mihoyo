extends MeshInstance3D

@export var plain_black_shell: bool = true

func _ready() -> void:
	# Keep the original node, transforms and collision shapes for cube cutaway.
	var bounds := mesh.get_aabb()
	var span_x := bounds.size.x
	var span_z := bounds.size.z
	if plain_black_shell:
		# Use the original boundary plane so adjoining faces remain connected.
		var black := StandardMaterial3D.new()
		black.albedo_color = Color.BLACK
		black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		black.roughness = 0.95
		black.cull_mode = BaseMaterial3D.CULL_DISABLED
		material_override = black
		return
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := BoxMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(String(get_path()).hash())
	for i in range(int(span_z / 0.12)):
		var cursor := bounds.position.x
		while cursor < bounds.end.x - 0.02:
			var length := minf(rng.randf_range(0.35, 0.9), bounds.end.x-cursor)
			box.size = Vector3(length, 0.022, 0.022)
			var t := Transform3D.IDENTITY
			t.origin = Vector3(cursor+length/2, rng.randf_range(-0.025,0.025), bounds.position.z + 0.035 + i * 0.12)
			surface.append_from(box, 0, t)
			cursor += length + rng.randf_range(0.06,0.24)
	mesh = surface.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("eeeeee")
	mat.metallic = 0.45
	mat.roughness = 0.4
	material_override = mat
	# Recessed matte surface receives the moving shadows through the slats.
	var receiver := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	# Each backing is recessed by 0.18: extend to the adjacent recessed
	# plane so perpendicular faces meet instead of leaving an open corner.
	plane.size = Vector2(span_x + 0.36, span_z + 0.36)
	receiver.mesh = plane
	receiver.position.y = -0.18
	var backing := StandardMaterial3D.new()
	backing.albedo_color = Color("242424")
	backing.roughness = 0.95
	backing.cull_mode = BaseMaterial3D.CULL_DISABLED
	receiver.material_override = backing
	add_child(receiver)
