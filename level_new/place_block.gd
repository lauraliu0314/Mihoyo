extends Node

## Hover an empty surface cell on a visible face, then left-click to drop a block.

const BOX_SCENE := "res://assets/decon/decon_block.tscn"
const DeconFx := preload("res://assets/decon/decon_fx.gd")
const XZ_MIN := -2.5
const XZ_MAX := 2.5
const Y_MIN := 0.5
const Y_MAX := 5.5

const HINT_PLACE := "只能放在脚下这一面的中间 4×4，每面只能放一次。连成直线的三块会消失"
const HINT_FACE_USED := "这一面已经放过方块，换一面再放"
const HINT_PREVIEW := "高亮的方块会消失"
const HINT_PREVIEW_MULTI := "有多种消法，放下后选择其中一排"
const HINT_CHOOSE := "有多种三连，点一种，这三块会消失"
const HINT_CLEARING := "方块已放上，马上碎裂"
const PLACE_LIMIT := 3
## Place slide is 0.2s. Hold long enough to see the block land, then shatter.
const CLEAR_REVEAL_SEC := 0.58

var _cube: Node3D
var _ghost: Node3D
var _hint: Label
var _stock: Label
var _stock_panel: PanelContainer
var _blocks_left := PLACE_LIMIT
var _used_faces: Array[Vector3] = []
var _has_hover := false
var _hover_cell := Vector3.ZERO
var _place_serial := 0
var _choosing := false
var _options: Array[Dictionary] = []
var _highlights: Array[MeshInstance3D] = []
var _previews: Array[MeshInstance3D] = []
var _preview_colors: Array[Color] = []
var _has_clear_preview := false
var _preview_cell := Vector3.ZERO
var _ghost_mat: StandardMaterial3D
var _ghost_color := Color(1.0, 1.0, 1.0, 0.38)
var _choice_layer: CanvasLayer
var _clearing := false


func _ready() -> void:
	_cube = get_parent() as Node3D
	if _cube != null and "place_limit" in _cube:
		_blocks_left = maxi(int(_cube.place_limit), 0)
	_ghost = Node3D.new()
	_ghost.name = "PlaceGhost"
	var block_size: float = preload("res://assets/decon/decon_style.gd").load_default().visual_scale()
	var rim := MeshInstance3D.new()
	var rim_mesh := BoxMesh.new()
	rim_mesh.size = Vector3.ONE * block_size
	rim.mesh = rim_mesh
	var rim_mat := StandardMaterial3D.new()
	rim_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rim_mat.albedo_color = Color(0.9, 0.9, 0.9, 0.08)
	rim.material_override = rim_mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(rim)
	var fill := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * block_size
	fill.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = _ghost_color
	_ghost_mat = mat
	fill.material_override = mat
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.add_child(fill)
	_ghost.visible = false
	_cube.add_child(_ghost)
	_add_hint()


func _process(_delta: float) -> void:
	_update_hover()
	_pulse_clear_preview()
	_pulse_pending_clear()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _clearing or (_cube != null and bool(_cube.get("flipping"))):
		return
	if _choosing:
		_try_choose_from_click()
		return
	if not _has_hover:
		return
	_place(_hover_cell)
	get_viewport().set_input_as_handled()


func _add_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var label := Label.new()
	label.text = HINT_PLACE
	_hint = label
	label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	label.offset_left = 24.0
	label.offset_top = -52.0
	label.offset_right = 720.0
	label.offset_bottom = -16.0
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Color(0.96, 0.96, 0.95))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(label)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -400.0
	panel.offset_top = -40.0
	panel.offset_right = -20.0
	panel.offset_bottom = 40.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.06, 0.88)
	style.border_color = Color(0.96, 0.96, 0.95, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	_stock_panel = panel
	layer.add_child(panel)

	var stock := Label.new()
	stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stock.add_theme_font_size_override("font_size", 34)
	stock.add_theme_color_override("font_color", Color(0.96, 0.96, 0.95))
	_stock = stock
	_refresh_stock()
	panel.add_child(stock)
	_show_stock_after_welcome()


func _show_stock_after_welcome() -> void:
	var welcome := _welcome_label()
	while is_instance_valid(welcome) and welcome.visible and is_inside_tree():
		var tree := get_tree()
		if tree == null:
			return
		await tree.process_frame
	if not is_inside_tree():
		return
	if _stock_panel != null and is_instance_valid(_stock_panel):
		_stock_panel.visible = true


func _welcome_label() -> CanvasItem:
	if _cube == null:
		return null
	var host := _cube.get_parent()
	if host == null:
		return null
	var ui := host.get_node_or_null("ui_ingame")
	if ui == null:
		return null
	return ui.get_node_or_null("welcome") as CanvasItem


func _update_hover() -> void:
	_has_hover = false
	_ghost.visible = false
	if _cube == null or _is_busy() or _blocks_left <= 0:
		_clear_clear_preview()
		return
	if _current_floor_used():
		_clear_clear_preview()
		if _hint != null:
			_hint.text = HINT_FACE_USED
		return
	if _hint != null and _hint.text == HINT_FACE_USED:
		_hint.text = HINT_PLACE
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		_clear_clear_preview()
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := _cube.to_local(cam.project_ray_origin(mouse))
	var direction := _cube.global_transform.basis.inverse() * cam.project_ray_normal(mouse)
	var picked: Variant = _pick_cell(origin, direction)
	if picked == null:
		_clear_clear_preview()
		return
	var cell := picked as Vector3
	if not _on_current_floor(cell) or not _in_clear_region(cell) or _face_used(cell) or _cell_blocked(cell):
		_clear_clear_preview()
		return
	_hover_cell = cell
	_has_hover = true
	_ghost.position = cell
	_ghost.visible = true
	_sync_clear_preview(cell)


func _is_busy() -> bool:
	return _choosing or _clearing or (_cube != null and bool(_cube.get("flipping")))


func _pick_cell(origin: Vector3, direction: Vector3) -> Variant:
	var best_t := INF
	var best: Variant = null
	for face in _faces():
		var axis := int(face["axis"])
		var plane := float(face["plane"])
		var dir_comp := direction[axis]
		if absf(dir_comp) < 0.00001:
			continue
		var t := (plane - origin[axis]) / dir_comp
		if t < 0.02 or t >= best_t:
			continue
		var point := origin + direction * t
		if not _on_face(point, axis):
			continue
		if not _face_is_visible(face["outward"] as Vector3):
			continue
		var cell := Vector3(
			_snap_center(point.x, XZ_MIN, XZ_MAX),
			_snap_center(point.y, Y_MIN, Y_MAX),
			_snap_center(point.z, XZ_MIN, XZ_MAX)
		)
		match axis:
			0:
				cell.x = float(face["center"])
			1:
				cell.y = float(face["center"])
			2:
				cell.z = float(face["center"])
		best_t = t
		best = cell
	return best


func _faces() -> Array[Dictionary]:
	return [
		{"axis": 0, "plane": -3.0, "center": -2.5, "outward": Vector3.LEFT},
		{"axis": 0, "plane": 3.0, "center": 2.5, "outward": Vector3.RIGHT},
		{"axis": 1, "plane": 0.0, "center": 0.5, "outward": Vector3.DOWN},
		{"axis": 1, "plane": 6.0, "center": 5.5, "outward": Vector3.UP},
		{"axis": 2, "plane": -3.0, "center": -2.5, "outward": Vector3(0, 0, -1)},
		{"axis": 2, "plane": 3.0, "center": 2.5, "outward": Vector3(0, 0, 1)},
	]


func _on_face(point: Vector3, axis: int) -> bool:
	if axis != 0 and (point.x < -3.02 or point.x > 3.02):
		return false
	if axis != 1 and (point.y < -0.02 or point.y > 6.02):
		return false
	if axis != 2 and (point.z < -3.02 or point.z > 3.02):
		return false
	return true


func _face_is_visible(outward_local: Vector3) -> bool:
	var walls := _cube.get_node_or_null("WALLS")
	if walls == null:
		return true
	var best_wall: Node3D = null
	var best_dot := -INF
	var outward_world := (_cube.global_transform.basis * outward_local).normalized()
	for child in walls.get_children():
		var wall := child as Node3D
		if wall == null:
			continue
		var center: Vector3 = _cube.get_center_global()
		var from_center: Vector3 = wall.global_position - center
		if from_center.length_squared() < 0.001:
			continue
		var align: float = from_center.normalized().dot(outward_world)
		if align > best_dot:
			best_dot = align
			best_wall = wall
	if best_wall == null:
		return true
	var mesh := best_wall.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return true
	return mesh.visible


func _cell_blocked(cell: Vector3) -> bool:
	if _is_exit_cell(cell):
		return true
	if _occupied_by_boxes(_cube.get_node_or_null("staticboxes"), cell):
		return true
	if _occupied_by_boxes(_cube, cell):
		return true
	var host := _cube.get_parent()
	if host == null:
		return false
	var player := host.get_node_or_null("Player") as Node3D
	if player == null:
		return false
	var local_player := _cube.to_local(player.global_position)
	return local_player.distance_to(cell) < 0.75


func _is_exit_cell(cell: Vector3) -> bool:
	if _cube == null:
		return false
	var exit_node := _cube.find_child("StaticBox_EXIT", true, false) as Node3D
	if exit_node == null:
		return false
	var local_pos: Vector3 = _cube.to_local(exit_node.global_position)
	var exit_cell := Vector3(
		_snap_center(local_pos.x, XZ_MIN, XZ_MAX),
		_snap_center(local_pos.y, Y_MIN, Y_MAX),
		_snap_center(local_pos.z, XZ_MIN, XZ_MAX)
	)
	return exit_cell.distance_to(cell) < 0.45


func _occupied_by_boxes(root: Node, cell: Vector3) -> bool:
	if root == null:
		return false
	for child in root.get_children():
		if child == _ghost or not (child is Node3D):
			continue
		var n := String(child.name)
		if "EXIT" in n:
			continue
		if "StaticBox" in n or "MovableBox" in n or "PlacedBox" in n:
			if (child as Node3D).position.distance_to(cell) < 0.45:
				return true
	return false


func _place(cell: Vector3) -> void:
	if _blocks_left <= 0 or not _on_current_floor(cell) or not _in_clear_region(cell) or _face_used(cell) or _cell_blocked(cell):
		return
	var packed := load(BOX_SCENE) as PackedScene
	if packed == null:
		return
	var box := packed.instantiate() as Node3D
	_place_serial += 1
	box.name = "StaticBoxPlaced%d" % _place_serial
	var root := _cube.get_node_or_null("staticboxes")
	if root == null:
		root = _cube
	box.position = cell
	root.add_child(box)
	if _cube.has_method("register_placed_box"):
		_cube.register_placed_box(box)
	DeconFx.play_place(box)
	_blocks_left -= 1
	_used_faces.append(_cell_outward(cell))
	_refresh_stock()
	_has_hover = false
	_ghost.visible = false
	_resolve_line(cell)


func _refresh_stock() -> void:
	if _stock == null:
		return
	_stock.text = "剩余可放置：%d" % _blocks_left
	if _blocks_left <= 0:
		_stock.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	else:
		_stock.add_theme_color_override("font_color", Color(0.96, 0.96, 0.95))


func _resolve_line(origin: Vector3) -> void:
	var lines := _lines_through(origin)
	if lines.is_empty():
		return
	if lines.size() == 1:
		_reveal_then_erase(lines[0])
		return
	_begin_choice(lines)


func _lines_through(origin: Vector3, assume_filled: bool = false) -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	# Face borders sit on two faces at once. Only the inner 4×4 of a 6×6 face can clear.
	if not _in_clear_region(origin):
		return lines
	var steps: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3(0, 0, 1)]
	for axis in range(3):
		var step: Vector3 = steps[axis]
		var run: Array[Vector3] = [origin]
		var forward: Vector3 = origin + step
		while _in_clear_region(forward) and _box_at(forward) != null:
			run.append(forward)
			forward += step
		var backward: Vector3 = origin - step
		while _in_clear_region(backward) and _box_at(backward) != null:
			run.insert(0, backward)
			backward -= step
		if run.size() < 3:
			continue
		var origin_index := run.find(origin)
		for start in range(run.size() - 2):
			if origin_index < start or origin_index > start + 2:
				continue
			var cells: Array[Vector3] = [run[start], run[start + 1], run[start + 2]]
			var nodes: Array[Node3D] = []
			var complete := true
			for spot in cells:
				if assume_filled and spot.distance_to(origin) < 0.2:
					continue
				var box := _box_at(spot)
				if box == null:
					complete = false
					break
				nodes.append(box)
			if not complete:
				continue
			lines.append({"cells": cells, "nodes": nodes, "axis": axis})
	return lines


func _begin_choice(lines: Array[Dictionary]) -> void:
	_clear_clear_preview()
	_choosing = true
	_options = lines
	_has_hover = false
	_ghost.visible = false
	if _hint != null:
		_hint.text = HINT_CHOOSE
	_show_choice_ui(lines)
	_paint_highlights(-1)


func _show_choice_ui(lines: Array[Dictionary]) -> void:
	_dismiss_choice_ui()
	_choice_layer = CanvasLayer.new()
	_choice_layer.layer = 30
	add_child(_choice_layer)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -480.0
	panel.offset_right = 480.0
	panel.offset_top = -248.0
	panel.offset_bottom = -36.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.06, 0.06, 0.06, 0.92)
	panel_style.set_corner_radius_all(14)
	panel_style.content_margin_left = 28.0
	panel_style.content_margin_right = 28.0
	panel_style.content_margin_top = 18.0
	panel_style.content_margin_bottom = 18.0
	panel.add_theme_stylebox_override("panel", panel_style)
	_choice_layer.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	panel.add_child(column)
	var title := Label.new()
	title.text = "选择要消除的一排"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.96, 0.96, 0.95))
	column.add_child(title)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	column.add_child(row)

	for index in lines.size():
		var button := Button.new()
		button.text = _choice_label(index)
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(160, 76)
		_style_choice_button(button, _option_color(index))
		button.pressed.connect(_commit_line.bind(index))
		button.mouse_entered.connect(_paint_highlights.bind(index))
		button.mouse_exited.connect(_paint_highlights.bind(-1))
		row.add_child(button)


func _style_choice_button(button: Button, color: Color) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(color.r, color.g, color.b, 0.92)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 28.0
	normal.content_margin_right = 28.0
	normal.content_margin_top = 14.0
	normal.content_margin_bottom = 14.0
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.2)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	var ink := Color(0.08, 0.08, 0.08) if color.get_luminance() > 0.55 else Color(0.96, 0.96, 0.95)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_font_size_override("font_size", 40)


func _try_choose_from_click() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var mouse := get_viewport().get_mouse_position()
	var origin := _cube.to_local(cam.project_ray_origin(mouse))
	var direction := _cube.global_transform.basis.inverse() * cam.project_ray_normal(mouse)
	var picked: Variant = _pick_cell(origin, direction)
	if picked == null:
		return
	var index := _option_at_cell(picked as Vector3)
	if index < 0:
		return
	_commit_line(index)
	get_viewport().set_input_as_handled()


func _option_at_cell(cell: Vector3) -> int:
	var found := -1
	for index in _options.size():
		if not _option_contains(_options[index], cell):
			continue
		if found >= 0:
			return -1
		found = index
	return found


func _option_contains(option: Dictionary, cell: Vector3) -> bool:
	var stored: Variant = option.get("cells", [])
	if not (stored is Array):
		return false
	var cells := stored as Array
	for index in cells.size():
		var spot: Vector3 = cells[index]
		if spot.distance_to(cell) < 0.45:
			return true
	return false


func _commit_line(index: int) -> void:
	if not _choosing or index < 0 or index >= _options.size():
		return
	var chosen: Dictionary = _options[index]
	_end_choice()
	_erase_option(chosen)


func _reveal_then_erase(option: Dictionary) -> void:
	_clearing = true
	_clear_clear_preview()
	if _hint != null:
		_hint.text = HINT_CLEARING
	_paint_pending_clear(option)
	get_tree().create_timer(CLEAR_REVEAL_SEC).timeout.connect(_finish_reveal_clear.bind(option), CONNECT_ONE_SHOT)


func _paint_pending_clear(option: Dictionary) -> void:
	_clear_highlights()
	var stored: Variant = option.get("nodes", [])
	if not (stored is Array):
		return
	for node in stored as Array:
		if node is Node3D and is_instance_valid(node):
			_add_highlight(node as Node3D, Color(0.15, 0.15, 0.15, 0.28))


func _finish_reveal_clear(option: Dictionary) -> void:
	if not is_inside_tree():
		return
	_clearing = false
	_clear_highlights()
	_erase_option(option)
	if not _choosing and _hint != null:
		_hint.text = HINT_PLACE


func _pulse_pending_clear() -> void:
	if not _clearing:
		return
	var wave := 0.16 + 0.22 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.014))
	for hint in _highlights:
		if not is_instance_valid(hint):
			continue
		var mat := hint.material_override as StandardMaterial3D
		if mat == null:
			continue
		mat.albedo_color = Color(0.15, 0.15, 0.15, wave)


func _erase_option(option: Dictionary) -> void:
	var stored: Variant = option.get("nodes", [])
	if stored is Array:
		var nodes := stored as Array
		for index in nodes.size():
			var node: Variant = nodes[index]
			if node is Node3D and is_instance_valid(node):
				_erase_box(node as Node3D)
	if _cube != null and _cube.has_method("update_cutaway_visibility"):
		_cube.call("update_cutaway_visibility")


func _erase_box(box: Node3D) -> void:
	if _cube != null:
		DeconFx.play_clear(_cube, box.global_position)
	var shapes: Array[Node] = box.find_children("*", "CollisionShape3D", true, false)
	for shape in shapes:
		var collision := shape as CollisionShape3D
		if collision != null:
			collision.disabled = true
	var piece := box.get_node_or_null("MeshInstance3D") as Node3D
	if piece == null:
		box.visible = false
		box.queue_free()
		return
	var crack := create_tween()
	crack.tween_property(piece, "scale", Vector3(1.08, 1.08, 1.08), 0.06)
	crack.tween_property(piece, "scale", Vector3(0.12, 0.12, 0.12), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	crack.tween_callback(box.queue_free)


func _end_choice() -> void:
	_choosing = false
	_options.clear()
	_clear_highlights()
	_dismiss_choice_ui()
	if _hint != null:
		_hint.text = HINT_PLACE


func _paint_highlights(hovered: int) -> void:
	_clear_highlights()
	if not _choosing:
		return
	for index in _options.size():
		var color := _option_color(index)
		color.a = 0.82 if hovered < 0 or hovered == index else 0.34
		var stored: Variant = _options[index].get("nodes", [])
		if not (stored is Array):
			continue
		var nodes := stored as Array
		for node_index in nodes.size():
			var node: Variant = nodes[node_index]
			if node is Node3D and is_instance_valid(node):
				_add_highlight(node as Node3D, color)


func _add_highlight(box: Node3D, color: Color) -> void:
	var hint := MeshInstance3D.new()
	hint.name = "MatchHint"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.04, 1.04, 1.04)
	hint.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	hint.material_override = mat
	hint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cube.add_child(hint)
	hint.global_position = box.global_position
	_highlights.append(hint)


func _clear_highlights() -> void:
	for hint in _highlights:
		if is_instance_valid(hint):
			hint.visible = false
			hint.queue_free()
	_highlights.clear()


func _dismiss_choice_ui() -> void:
	if _choice_layer != null and is_instance_valid(_choice_layer):
		_choice_layer.queue_free()
	_choice_layer = null


func _sync_clear_preview(cell: Vector3) -> void:
	if _has_clear_preview and _preview_cell.distance_to(cell) < 0.05:
		return
	_clear_clear_preview()
	var lines := _lines_through(cell, true)
	if lines.is_empty():
		return
	_has_clear_preview = true
	_preview_cell = cell
	var multi := lines.size() > 1
	if multi:
		_ghost_color = Color(0.82, 0.82, 0.82, 0.55)
	else:
		_ghost_color = Color(1.0, 1.0, 1.0, 0.62)
	if _hint != null:
		_hint.text = HINT_PREVIEW_MULTI if multi else HINT_PREVIEW
	var marked: Array[Vector3] = []
	for index in lines.size():
		var color := _option_color(index) if multi else Color(0.15, 0.15, 0.15)
		var stored: Variant = lines[index].get("cells", [])
		if not (stored is Array):
			continue
		var cells := stored as Array
		for cell_index in cells.size():
			var spot: Vector3 = cells[cell_index]
			if spot.distance_to(cell) < 0.2 or _contains_cell(marked, spot):
				continue
			var box := _box_at(spot)
			if box == null:
				continue
			marked.append(spot)
			_add_preview(box, color)


func _contains_cell(cells: Array[Vector3], spot: Vector3) -> bool:
	for existing in cells:
		if existing.distance_to(spot) < 0.2:
			return true
	return false


func _add_preview(box: Node3D, color: Color) -> void:
	var hint := MeshInstance3D.new()
	hint.name = "MatchHint"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.08, 1.08, 1.08)
	hint.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	hint.material_override = mat
	hint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cube.add_child(hint)
	hint.global_position = box.global_position
	_previews.append(hint)
	_preview_colors.append(color)


func _pulse_clear_preview() -> void:
	if not _has_clear_preview:
		return
	var wave := 0.5 + 0.38 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.008))
	for index in _previews.size():
		var hint := _previews[index]
		if not is_instance_valid(hint):
			continue
		var mat := hint.material_override as StandardMaterial3D
		if mat == null:
			continue
		var color := _preview_colors[index]
		color.a = wave
		mat.albedo_color = color
	if _ghost_mat != null:
		var ghost := _ghost_color
		ghost.a = 0.25 + wave * 0.65
		_ghost_mat.albedo_color = ghost


func _clear_clear_preview() -> void:
	if not _has_clear_preview and _previews.is_empty():
		return
	_has_clear_preview = false
	for hint in _previews:
		if is_instance_valid(hint):
			hint.visible = false
			hint.queue_free()
	_previews.clear()
	_preview_colors.clear()
	_ghost_color = Color(1.0, 1.0, 1.0, 0.38)
	if _ghost_mat != null:
		_ghost_mat.albedo_color = _ghost_color
	if not _choosing and not _clearing and _hint != null:
		_hint.text = HINT_PLACE


func _box_at(cell: Vector3) -> Node3D:
	var placed := _find_box(_cube.get_node_or_null("staticboxes"), cell)
	if placed != null:
		return placed
	return _find_box(_cube, cell)


func _find_box(root: Node, cell: Vector3) -> Node3D:
	if root == null:
		return null
	for child in root.get_children():
		if child == _ghost or not (child is Node3D):
			continue
		var body := child as Node3D
		var n := String(body.name)
		if "EXIT" in n or "MatchHint" in n or n == "PlaceGhost":
			continue
		if "StaticBox" in n or "MovableBox" in n:
			if body.position.distance_to(cell) < 0.45:
				return body
	return null


func _face_used(cell: Vector3) -> bool:
	var outward := _cell_outward(cell)
	if outward.length_squared() < 0.5:
		return true
	for used in _used_faces:
		if used.distance_to(outward) < 0.2:
			return true
	return false


func _current_floor_used() -> bool:
	if _cube == null:
		return false
	var basis := _cube.global_transform.basis
	for used in _used_faces:
		var world_outward := (basis * used).normalized()
		if world_outward.dot(Vector3.DOWN) > 0.9:
			return true
	return false


func _on_current_floor(cell: Vector3) -> bool:
	if _cube == null:
		return false
	var outward := _cell_outward(cell)
	if outward.length_squared() < 0.5:
		return false
	var world_outward: Vector3 = (_cube.global_transform.basis * outward).normalized()
	return world_outward.dot(Vector3.DOWN) > 0.9


func _cell_outward(cell: Vector3) -> Vector3:
	if _is_outer_center(cell.x, -2.5, 2.5):
		return Vector3(signf(cell.x), 0.0, 0.0)
	if _is_outer_center(cell.y, 0.5, 5.5):
		if cell.y < 3.0:
			return Vector3.DOWN
		return Vector3.UP
	if _is_outer_center(cell.z, -2.5, 2.5):
		return Vector3(0.0, 0.0, signf(cell.z))
	return Vector3.ZERO


func _in_clear_region(cell: Vector3) -> bool:
	var outer_x := _is_outer_center(cell.x, -2.5, 2.5)
	var outer_y := _is_outer_center(cell.y, 0.5, 5.5)
	var outer_z := _is_outer_center(cell.z, -2.5, 2.5)
	return int(outer_x) + int(outer_y) + int(outer_z) == 1


func _is_outer_center(value: float, low: float, high: float) -> bool:
	return absf(value - low) < 0.2 or absf(value - high) < 0.2


func _choice_label(index: int) -> String:
	var labels := "ABCDEFGH"
	if index >= 0 and index < labels.length():
		return labels[index]
	return str(index + 1)


func _option_color(index: int) -> Color:
	match index % 2:
		0:
			return Color(0.98, 0.98, 0.97)
		_:
			return Color(0.05, 0.05, 0.05)


func _snap_center(value: float, lo: float, hi: float) -> float:
	return clampf(snappedf(value - 0.5, 1.0) + 0.5, lo, hi)
