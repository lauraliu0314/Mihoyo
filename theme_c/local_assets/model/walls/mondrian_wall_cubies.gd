@tool
extends Node3D

## Shared thickness for the irregular black seams. Each neighboring tile contributes half.
@export_range(0.01, 0.14, 0.005) var line_width: float = 0.055:
	set(value):
		line_width = value
		if is_inside_tree():
			call_deferred("refresh_layout")

var _stickers: Array[Node3D] = []


func _ready() -> void:
	_collect_stickers()
	call_deferred("refresh_layout")


func _collect_stickers() -> void:
	_stickers.clear()
	for cubie in get_children():
		if not cubie is Node3D:
			continue
		for sticker in cubie.get_children():
			if sticker is Node3D and sticker.has_method("set_edge_gaps"):
				_stickers.append(sticker)


func _axis(vector: Vector3) -> Vector3i:
	return Vector3i(roundi(vector.x), roundi(vector.y), roundi(vector.z))


func _key(normal: Vector3i, center: Vector3) -> String:
	return "%d,%d,%d|%d,%d,%d" % [normal.x, normal.y, normal.z, roundi(center.x * 2.0), roundi(center.y * 2.0), roundi(center.z * 2.0)]


func _gap(sticker: Node3D, other: Node3D, own_bit: int, other_bit: int) -> float:
	if other == null:
		return line_width * 0.5
	if bool(sticker.get("is_hole")) or bool(other.get("is_hole")):
		return line_width * 0.5
	if sticker.get("color_state") == other.get("color_state") and (int(sticker.get("force_edges")) & own_bit) == 0 and (int(other.get("force_edges")) & other_bit) == 0:
		return 0.0
	return line_width * 0.5


func refresh_layout() -> void:
	if Engine.is_editor_hint():
		_collect_stickers()
	var by_face_cell: Dictionary = {}
	var frames: Dictionary = {}
	var inverse := global_transform.affine_inverse()
	for sticker in _stickers:
		if not is_instance_valid(sticker):
			continue
		var pose: Transform3D = inverse * sticker.global_transform
		var normal := _axis(pose.basis.z)
		var right := _axis(pose.basis.x)
		var up := _axis(pose.basis.y)
		frames[sticker] = [normal, right, up, pose.origin]
		by_face_cell[_key(normal, pose.origin)] = sticker
	for sticker in frames:
		var frame: Array = frames[sticker]
		var normal: Vector3i = frame[0]
		var right: Vector3i = frame[1]
		var up: Vector3i = frame[2]
		var center: Vector3 = frame[3]
		var left_neighbor := by_face_cell.get(_key(normal, center - Vector3(right))) as Node3D
		var right_neighbor := by_face_cell.get(_key(normal, center + Vector3(right))) as Node3D
		var top_neighbor := by_face_cell.get(_key(normal, center + Vector3(up))) as Node3D
		var bottom_neighbor := by_face_cell.get(_key(normal, center - Vector3(up))) as Node3D
		sticker.call("set_edge_gaps",
			_gap(sticker, left_neighbor, 1, 2),
			_gap(sticker, right_neighbor, 2, 1),
			_gap(sticker, top_neighbor, 4, 8),
			_gap(sticker, bottom_neighbor, 8, 4))


func refresh_visibility(camera: Camera3D, threshold: float, cube_center: Vector3) -> void:
	if camera == null:
		return
	var to_camera := (camera.global_position - cube_center).normalized()
	for sticker in _stickers:
		if is_instance_valid(sticker):
			var inward := sticker.global_transform.basis.z.normalized()
			sticker.visible = -inward.dot(to_camera) <= threshold
