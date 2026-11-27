extends Node3D
signal layer_turn_finished(axis: Vector3, slice: float, direction: int)
## Mouse-drag Rubik turns for the standalone Level 1 design demo.
## A drag across a visible face turns its row; a drag along it turns its column.
## Every selected surface sticker and every obstacle in that cubie slice moves.

@export var cube_path: NodePath = ^"../Node3D"
@export var player_path: NodePath = ^"../Player"
@export var drag_threshold_pixels: float = 24.0
@export var turn_duration: float = 0.48
@export var require_marker_in_slice: bool = false
@export var markers_follow_layer: bool = true
@export_group("选层预览外观")
@export var preview_available_color: Color = Color(0.2, 0.9, 1.0, 0.55)
@export var preview_blocked_color: Color = Color(1.0, 0.16, 0.12, 0.68)
@export var preview_tile_size: Vector2 = Vector2(0.92, 0.92)
@export_group("提示文字")
@export_multiline var free_turn_hint: String = "左键按住立方体格子拖动：横拖转一排，竖拖转一列"
@export_multiline var marked_turn_hint: String = "按住双箭头标记，沿箭头拖动；松开后转动标记所在的整层"
@export var blocked_hint_color: Color = Color(1.0, 0.48, 0.43)

const GRID_SIZE := 6
const CELL_HALF := 2.5
const DIRECTIONS := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]

var _cube: Node3D
var _player: CharacterBody3D
var _press_pos := Vector2.ZERO
var _hit_local := Vector3.ZERO
var _hit_normal := Vector3.ZERO
var _dragging := false
var _choice_ready := false
var _turning := false
var _axis := Vector3.ZERO
var _slice := 0.0
var _direction := 1
var _preview: Node3D
var _preview_material: StandardMaterial3D
var _block_reason := ""
var _status: Label
var _normal_hint_color := Color(0.96, 0.98, 1.0)


func _ready() -> void:
	_cube = get_node_or_null(cube_path) as Node3D
	_player = get_node_or_null(player_path) as CharacterBody3D
	if _cube == null or _player == null:
		push_error("Rubik layer: cube or player was not found")
		set_process_unhandled_input(false)
		return
	_status = get_node_or_null("RubikHintLayer/RubikHint") as Label
	if _status != null:
		_normal_hint_color = _status.get_theme_color("font_color")
	if require_marker_in_slice:
		_set_status(marked_turn_hint)
	else:
		_set_status(free_turn_hint)
	if _cube.has_signal("flip_started"):
		_cube.flip_started.connect(_cancel_drag)


func _set_status(value: String, blocked: bool = false) -> void:
	if _status != null:
		_status.text = value
		_status.add_theme_color_override("font_color", blocked_hint_color if blocked else _normal_hint_color)


func _unhandled_input(event: InputEvent) -> void:
	if _cube == null or _turning:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _dragging:
		_cancel_drag()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _dragging:
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_drag(event.position)
		else:
			_end_drag(event.position)
	elif event is InputEventMouseMotion and _dragging:
		_update_drag(event.position)


func _begin_drag(mouse: Vector2) -> void:
	if _cube.get("flipping") == true:
		return
	var hit := _pick_turn_marker(mouse)
	if hit.is_empty():
		hit = _pick_visible_face(mouse)
	if hit.is_empty():
		return
	_press_pos = mouse
	_hit_local = hit["point"]
	_hit_normal = hit["normal"]
	_dragging = true
	_choice_ready = false
	_block_reason = ""
	_clear_preview()
	if require_marker_in_slice:
		_set_status("沿双箭头拖动；回拖到起点、右键或 Esc 可取消")
	else:
		_set_status("横拖选一排，竖拖选一列；回拖到起点、右键或 Esc 可取消")
	get_viewport().set_input_as_handled()


func _update_drag(mouse: Vector2) -> void:
	var delta := mouse - _press_pos
	if delta.length() < drag_threshold_pixels:
		_choice_ready = false
		_block_reason = ""
		_clear_preview()
		_set_status("已回到起点附近；现在松开不会旋转")
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var right := _face_right(_hit_normal)
	var up := _hit_normal.cross(right).normalized()
	var right_2d := _screen_direction(cam, _hit_local, right)
	var up_2d := _screen_direction(cam, _hit_local, up)
	if right_2d.length_squared() < 0.01 or up_2d.length_squared() < 0.01:
		return
	var horizontal := delta.dot(right_2d)
	var vertical := delta.dot(up_2d)
	if maxf(absf(horizontal), absf(vertical)) < 1.3 * minf(absf(horizontal), absf(vertical)):
		_choice_ready = false
		_block_reason = ""
		_clear_preview()
		_set_status("方向不明确；调整拖动方向，或右键 / Esc 取消")
		return
	var next_axis := up if absf(horizontal) > absf(vertical) else right
	var cubie := _cubie_offset(_hit_local)
	var next_slice := _nearest_cell(cubie.dot(next_axis))
	var selection_changed := not _choice_ready or next_axis != _axis or not is_equal_approx(next_slice, _slice)
	_axis = next_axis
	_slice = next_slice
	var tangent := _axis.cross(_hit_local - _center())
	var tangent_2d := _screen_direction(cam, _hit_local, tangent)
	_direction = 1 if delta.dot(tangent_2d) >= 0.0 else -1
	_choice_ready = true
	_block_reason = _turn_block_reason(_axis, _slice)
	if selection_changed or _preview == null:
		_show_preview()
	_set_preview_blocked(not _block_reason.is_empty())
	if _block_reason.is_empty():
		_set_status("已选中整层；松开旋转 90°。可调整方向，右键 / Esc 取消")
	else:
		_set_status("无法旋转：%s。此时松开不会旋转；可改选或取消" % _block_reason, true)
	get_viewport().set_input_as_handled()


func _end_drag(mouse: Vector2) -> void:
	if not _dragging:
		return
	_update_drag(mouse)
	_dragging = false
	if not _choice_ready:
		_clear_preview()
		_set_status("已放弃本次旋转")
		return
	_choice_ready = false
	if not _block_reason.is_empty():
		_clear_preview()
		_set_status("无法旋转：%s。请换一层或等待条件解除" % _block_reason, true)
		return
	turn_layer(_axis, _slice, _direction)


func _cancel_drag() -> void:
	_dragging = false
	_choice_ready = false
	_block_reason = ""
	_clear_preview()
	if not _turning:
		_set_status("已取消转动；重新按住格子即可选择")


func _pick_visible_face(mouse: Vector2) -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return {}
	var origin := _cube.to_local(cam.project_ray_origin(mouse))
	var direction := (_cube.global_transform.basis.inverse() * cam.project_ray_normal(mouse)).normalized()
	var camera_direction := (cam.global_position - _cube.to_global(_center())).normalized()
	var best_t := INF
	var answer: Dictionary = {}
	for normal in DIRECTIONS:
		var face_normal: Vector3 = normal
		var world_normal := (_cube.global_transform.basis * face_normal).normalized()
		if world_normal.dot(camera_direction) > float(_cube.get("wall_visible_dot")):
			continue
		var plane_point := _center() + face_normal * float(_cube.get("cube_half_extent"))
		var denominator := direction.dot(face_normal)
		if absf(denominator) < 0.0001:
			continue
		var t := (plane_point - origin).dot(face_normal) / denominator
		if t <= 0.0 or t >= best_t:
			continue
		var point := origin + direction * t
		var relative := point - _center()
		var within := true
		for i in range(3):
			if absf(face_normal[i]) < 0.5 and absf(relative[i]) > float(_cube.get("cube_half_extent")) - 0.02:
				within = false
		if within:
			best_t = t
			answer = {"point": point, "normal": face_normal}
	return answer


func _turn_markers() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var root := _cube.get_node_or_null("turn_markers")
	if root != null:
		for child in root.get_children():
			if child is Node3D and child.has_method("pick_from_mouse"):
				result.append(child)
	return result


func _pick_turn_marker(mouse: Vector2) -> Dictionary:
	if not require_marker_in_slice:
		return {}
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var best_distance := INF
	var answer: Dictionary = {}
	for marker in _turn_markers():
		var hit: Dictionary = marker.call("pick_from_mouse", camera, mouse)
		if hit.is_empty() or float(hit["distance"]) >= best_distance:
			continue
		best_distance = float(hit["distance"])
		answer = {"point": _cube.to_local(hit["point"]), "normal": (_cube.global_basis.inverse() * hit["normal"]).normalized()}
	return answer


func _face_right(normal: Vector3) -> Vector3:
	if absf(normal.y) > 0.5:
		return Vector3.RIGHT
	return Vector3.UP.cross(normal).normalized()


func _screen_direction(cam: Camera3D, local_point: Vector3, local_vector: Vector3) -> Vector2:
	var start := cam.unproject_position(_cube.to_global(local_point))
	var finish := cam.unproject_position(_cube.to_global(local_point + local_vector.normalized()))
	return (finish - start).normalized()


func _center() -> Vector3:
	return Vector3(0.0, float(_cube.get("cube_half_extent")), 0.0)


func _nearest_cell(value: float) -> float:
	return clampf(roundf(value - 0.5) + 0.5, -CELL_HALF, CELL_HALF)


func _cubie_offset(point: Vector3) -> Vector3:
	var offset := point - _center()
	return Vector3(_nearest_cell(offset.x), _nearest_cell(offset.y), _nearest_cell(offset.z))


func _in_slice(local_point: Vector3, axis: Vector3, slice: float) -> bool:
	return absf(_nearest_cell(_cubie_offset(local_point).dot(axis)) - slice) < 0.1


func _clear_preview() -> void:
	if _preview != null:
		_preview.queue_free()
		_preview = null
	_preview_material = null


func _set_preview_blocked(blocked: bool) -> void:
	if _preview_material != null:
		_preview_material.albedo_color = preview_blocked_color if blocked else preview_available_color


func _show_preview() -> void:
	_clear_preview()
	_preview = Node3D.new()
	_preview.name = "SelectedLayerPreview"
	_cube.add_child(_preview)
	_preview_material = StandardMaterial3D.new()
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.no_depth_test = false
	_preview_material.albedo_color = preview_available_color
	var mesh := PlaneMesh.new()
	mesh.size = preview_tile_size
	var cam := get_viewport().get_camera_3d()
	var camera_direction := (cam.global_position - _cube.to_global(_center())).normalized()
	for normal in DIRECTIONS:
		var face_normal: Vector3 = normal
		var world_normal := (_cube.global_transform.basis * face_normal).normalized()
		if world_normal.dot(camera_direction) > float(_cube.get("wall_visible_dot")):
			continue
		var right := _face_right(face_normal)
		var up := face_normal.cross(right).normalized()
		for row in range(GRID_SIZE):
			for col in range(GRID_SIZE):
				var cubie := _center() + face_normal * CELL_HALF + right * (float(col) - CELL_HALF) + up * (float(row) - CELL_HALF)
				if not _in_slice(cubie, _axis, _slice):
					continue
				var tile := MeshInstance3D.new()
				tile.mesh = mesh
				tile.material_override = _preview_material
				_preview.add_child(tile)
				tile.position = _center() + face_normal * (float(_cube.get("cube_half_extent")) - 0.04) + right * (float(col) - CELL_HALF) + up * (float(row) - CELL_HALF)
				tile.quaternion = Quaternion(Vector3.UP, -face_normal)


func _movable_nodes() -> Array[Node3D]:
	var result: Array[Node3D] = []
	var wall_cubies := _cube.get_node_or_null("WallCubies")
	if wall_cubies != null:
		for cubie in wall_cubies.get_children():
			if cubie is Node3D:
				result.append(cubie)
	var staticboxes := _cube.get_node_or_null("staticboxes")
	if staticboxes != null:
		for child in staticboxes.get_children():
			if child is Node3D and not child.is_in_group("rubik_anchor"):
				result.append(child)
	for child in _cube.get_children():
		if child is Node3D and (child.name.begins_with("MovableBox") or child.name.begins_with("DeadlyBox") or child.name == "StaticBox_EXIT") and not child.is_in_group("rubik_anchor"):
			result.append(child)
	if markers_follow_layer:
		for marker in _turn_markers():
			result.append(marker)
	return result


func _turn_block_reason(axis: Vector3, slice: float) -> String:
	if _turning or _cube.get("flipping") == true:
		return "立方体正在转动"
	if _cube.get("portal_locked") == true:
		return "当前交互尚未结束"
	if _in_slice(_cube.to_local(_player.global_position), axis, slice):
		return "Bready 正站在这一层上"
	if require_marker_in_slice:
		var camera := get_viewport().get_camera_3d()
		var visible_marker_on_slice := false
		var matching_marker := false
		for marker in _turn_markers():
			if camera == null or not marker.call("is_facing_camera", camera):
				continue
			if not _in_slice(_cube.to_local(marker.global_position), axis, slice):
				continue
			visible_marker_on_slice = true
			var marked_axis: Vector3 = marker.call("get_turn_axis", _cube)
			if absf(marked_axis.normalized().dot(axis.normalized())) > 0.95:
				matching_marker = true
		if not matching_marker:
			return "请沿双箭头拖动" if visible_marker_on_slice else "这一层没有可见的旋转标记"
	for item in _movable_nodes():
		if not _in_slice(_cube.to_local(item.global_position), axis, slice):
			continue
		if item.has_method("is_blocking_cube_motion") and item.call("is_blocking_cube_motion") == true:
			return "这一层的道具正在下落"
		if item is RigidBody3D and (item as RigidBody3D).linear_velocity.length() > 0.15:
			return "这一层的道具还在移动"
	return ""


func turn_layer(axis: Vector3, slice: float, direction: int) -> bool:
	if _cube == null:
		return false
	var reason := _turn_block_reason(axis, slice)
	if not reason.is_empty():
		_clear_preview()
		_set_status("无法旋转：%s。请换一层或等待条件解除" % reason, true)
		return false
	var moving: Array[Node3D] = []
	for item in _movable_nodes():
		if _in_slice(_cube.to_local(item.global_position), axis, slice):
			moving.append(item)
	if _cube.has_method("begin_layer_turn_visibility"):
		_cube.call("begin_layer_turn_visibility", moving)
	_turning = true
	_cube.set("flipping", true)
	var pivot := Node3D.new()
	pivot.name = "RubikMovingSlice"
	_cube.add_child(pivot)
	pivot.position = _center()
	var parents: Dictionary = {}
	var rigid_states: Dictionary = {}
	for item in moving:
		parents[item] = item.get_parent()
		if item is RigidBody3D:
			rigid_states[item] = (item as RigidBody3D).freeze
			(item as RigidBody3D).linear_velocity = Vector3.ZERO
			(item as RigidBody3D).angular_velocity = Vector3.ZERO
			(item as RigidBody3D).freeze = true
		item.reparent(pivot, true)
	if _preview != null:
		_preview.reparent(pivot, true)
		_preview = null
	var angle := float(direction) * PI / 2.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_turn_progress.bind(pivot, axis, angle), 0.0, 1.0, turn_duration)
	await tween.finished
	pivot.quaternion = Quaternion(axis, angle)
	for item in moving:
		if is_instance_valid(item):
			item.reparent(parents[item], true)
			item.global_transform.basis = item.global_transform.basis.orthonormalized()
			if item is RigidBody3D:
				(item as RigidBody3D).freeze = rigid_states[item]
	if _cube.has_method("end_layer_turn_visibility"):
		_cube.call("end_layer_turn_visibility")
	pivot.queue_free()
	_cube.set("flipping", false)
	if _cube.has_method("_bind_props_to_walls"):
		_cube.call("_bind_props_to_walls")
	var wall_cubies := _cube.get_node_or_null("WallCubies")
	if wall_cubies != null and wall_cubies.has_method("refresh_layout"):
		wall_cubies.call("refresh_layout")
	_cube.call("update_cutaway_visibility")
	_turning = false
	_set_status("已转动一层。继续走动，观察通路与道具位置的变化")
	layer_turn_finished.emit(axis, slice, direction)
	return true


func _set_turn_progress(progress: float, pivot: Node3D, axis: Vector3, angle: float) -> void:
	pivot.quaternion = Quaternion(axis, angle * progress)
	_cube.call("update_cutaway_visibility")
