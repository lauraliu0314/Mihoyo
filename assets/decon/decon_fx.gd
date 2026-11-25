extends Node3D

## Place-in and burst effects made of pencil strokes. No collision and no particles.


static func play_place(block: Node3D) -> void:
	var host := Node3D.new()
	host.name = "PlaceFx"
	host.set_script(load("res://assets/decon/decon_fx.gd"))
	block.add_child(host)
	host.call("run_place", block)


static func play_clear(cube: Node3D, world_pos: Vector3) -> void:
	var host := Node3D.new()
	host.name = "ClearFx"
	host.set_script(load("res://assets/decon/decon_fx.gd"))
	cube.add_child(host)
	host.call("run_clear", cube.to_local(world_pos))


var _fade_mats: Array[StandardMaterial3D] = []


func run_place(block: Node3D) -> void:
	var outward := _outward(block)
	var piece := block.get_node_or_null("MeshInstance3D") as Node3D
	if piece != null:
		var rest := piece.position
		piece.position = rest + outward * 0.35
		var slide := create_tween()
		slide.tween_property(piece, "position", rest, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var flash := _piece(Vector3(0.92, 0.92, 0.92), Color(0.92, 0.92, 0.92, 0.28))
	add_child(flash)
	var fade := create_tween()
	fade.tween_method(_fade_all, 0.28, 0.0, 0.2)
	fade.tween_interval(0.05)
	fade.tween_callback(queue_free)


func run_clear(local_pos: Vector3) -> void:
	position = local_pos
	var from_center := local_pos - Vector3(0.0, 3.0, 0.0)
	var outward := Vector3.UP if from_center.length_squared() < 0.001 else from_center.normalized()
	var dirs: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN,
		Vector3(0, 0, 1), Vector3(0, 0, -1),
		Vector3(0.7, 0.7, 0.2).normalized(),
		Vector3(-0.4, 0.8, -0.5).normalized(),
	]
	for index in dirs.size():
		var long_axis := index % 3
		var size := Vector3(0.14, 0.1, 0.08)
		size[long_axis] = 0.36 if index < 6 else 0.22
		var color := Color(0.86, 0.86, 0.86, 0.72) if index % 2 == 0 else Color(0.16, 0.16, 0.16, 0.78)
		var piece := _piece(size, color)
		piece.rotation = Vector3(0.15 * float(index), 0.2 * float(index % 3), 0.0)
		add_child(piece)
		var travel := (dirs[index] + outward * 0.85).normalized() * lerpf(0.6, 1.4, float(index) / float(dirs.size() - 1))
		var spin := piece.rotation + Vector3(1.4, -1.1, 0.8) * (1.0 if index % 2 == 0 else -1.0)
		var motion := create_tween()
		motion.set_parallel(true)
		motion.tween_property(piece, "position", travel, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_property(piece, "rotation", spin, 0.45)
	var fade := create_tween()
	fade.tween_method(_fade_all, 1.0, 0.0, 0.45)
	fade.tween_interval(0.05)
	fade.tween_callback(queue_free)


func _fade_all(alpha: float) -> void:
	for mat in _fade_mats:
		var color := mat.albedo_color
		color.a = alpha
		mat.albedo_color = color


func _piece(size: Vector3, color: Color) -> MeshInstance3D:
	var mesh_node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	mesh_node.material_override = mat
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fade_mats.append(mat)
	return mesh_node


func _outward(block: Node3D) -> Vector3:
	var from_center := block.position - Vector3(0.0, 3.0, 0.0)
	if from_center.length_squared() < 0.001:
		return Vector3.UP
	return from_center.normalized()
