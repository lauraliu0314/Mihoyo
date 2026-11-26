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
		Vector3(1, 1, 0).normalized(), Vector3(-1, 1, 0).normalized(),
		Vector3(1, 0, 1).normalized(), Vector3(-1, 0, 1).normalized(),
		Vector3(0.4, 0.85, 0.5).normalized(), Vector3(-0.5, 0.75, -0.45).normalized(),
		Vector3(0.85, -0.35, 0.4).normalized(), Vector3(-0.7, -0.4, -0.6).normalized(),
		Vector3(0.2, 0.4, -0.9).normalized(), Vector3(-0.15, -0.9, 0.35).normalized(),
	]
	for index in dirs.size():
		var long_axis := index % 3
		var size := Vector3(0.16, 0.11, 0.09)
		size[long_axis] = 0.46 if index < 8 else 0.28
		var color := burst_color(index)
		var piece := _piece(size, color)
		piece.rotation = Vector3(0.15 * float(index), 0.2 * float(index % 3), 0.12 * float(index))
		add_child(piece)
		var travel := (dirs[index] + outward * 0.85).normalized() * lerpf(0.9, 2.2, float(index) / float(dirs.size() - 1))
		var spin := piece.rotation + Vector3(1.6, -1.3, 0.9) * (1.0 if index % 2 == 0 else -1.0)
		var motion := create_tween()
		motion.set_parallel(true)
		motion.tween_property(piece, "position", travel, 0.58).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		motion.tween_property(piece, "rotation", spin, 0.58)
	var fade := create_tween()
	fade.tween_interval(0.12)
	fade.tween_method(_fade_all, 1.0, 0.0, 0.5)
	fade.tween_interval(0.05)
	fade.tween_callback(queue_free)


static func burst_color(index: int) -> Color:
	return Color.from_hsv(_burst_hue(index), 0.9, 1.0, 1.0)


static func _burst_hue(index: int) -> float:
	var t := fposmod(float(index) * 0.618, 1.0)
	if t < 0.78:
		var u := t / 0.78
		if u < 0.72:
			return lerpf(0.0, 0.16, u / 0.72)
		return lerpf(0.9, 0.99, (u - 0.72) / 0.28)
	return lerpf(0.32, 0.62, (t - 0.78) / 0.22)


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
