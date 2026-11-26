extends Node3D

## Place and remove fixed wall blocks with the mouse.
@export var wall_half_extent: float = 4.0
@export var burn_timer_enabled := true
const BLOCK_SCENE: PackedScene = preload("res://theme_b/runtime/assets/model/box/static_box_ice.tscn")

var _player: Node3D
var _cube: Node3D
var _blocks_root: Node3D
var _walls_root: Node3D
var _available := 1
var _mode := ""
var _target := Vector3.ZERO
var _selected_block: Node3D
var _hover_block: Node3D
var _has_target := false
var _preview: MeshInstance3D
var _preview_material: StandardMaterial3D
const BURN_DURATION := 30.0
const BURN_END_SCALE := 0.30
const BURN_COLLAPSE_DURATION := 0.22
var burn_remaining := BURN_DURATION
var _burning_block: Node3D
var _burn_label: Label


func _ready() -> void:
	_player = get_parent().get_node_or_null("Player") as Node3D
	_cube = get_parent().get_node_or_null("Node3D") as Node3D
	_blocks_root = _cube.get_node_or_null("staticboxes") as Node3D if _cube else null
	_walls_root = _cube.get_node_or_null("WALLS") as Node3D if _cube else null
	_preview = MeshInstance3D.new()
	_preview.name = "ConstructionPreview"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_preview.mesh = mesh
	var mat := StandardMaterial3D.new()
	_preview_material = mat
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.albedo_color = Color(1.0, 0.8, 0.15, 0.48)
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview.material_override = _preview_material
	_preview.visible = false
	_cube.add_child(_preview)
	var hud := CanvasLayer.new()
	add_child(hud)
	_burn_label = Label.new()
	_burn_label.position = Vector2(24, 112)
	_burn_label.add_theme_font_size_override("font_size", 32)
	hud.add_child(_burn_label)
	_update_burn_label()


func _process(_delta: float) -> void:
	_tick_burn(_delta)
	if _mode == "":
		return
	if _mode == "armed":
		_update_target_at(get_viewport().get_mouse_position())

func _tick_burn(delta: float) -> void:
	if not burn_timer_enabled:
		_update_burn_label()
		return
	if is_instance_valid(_burning_block) and not _burning_block.is_queued_for_deletion():
		burn_remaining = maxf(0.0, burn_remaining - delta)
		_update_burn_visual()
		if burn_remaining <= 0.0:
			_play_burn_collapse()
			# Remove the body, not merely the visual, exactly when fuel runs out.
			if _burning_block is CollisionObject3D:
				_burning_block.collision_layer = 0
				_burning_block.collision_mask = 0
			_burning_block.queue_free()
			_burning_block = null
			_available = 0
			_cancel_mode()
	_update_burn_label()

func _update_burn_visual() -> void:
	if not is_instance_valid(_burning_block):
		return
	var visual := _burning_block.get_node_or_null("LineArchitecture") as MeshInstance3D
	if visual == null:
		return
	var progress := 1.0 - burn_remaining / BURN_DURATION if burn_timer_enabled else 0.0
	visual.scale = Vector3.ONE * lerpf(1.0, BURN_END_SCALE, progress)
	if visual.material_override is ShaderMaterial:
		visual.material_override.set_shader_parameter("burn_progress", progress)
		visual.material_override.set_shader_parameter("burn_enabled", true)
	for child in visual.get_children():
		if child is MultiMeshInstance3D and "burn_progress" in child:
			child.burn_progress = progress

func _play_burn_collapse() -> void:
	var visual := _burning_block.get_node_or_null("LineArchitecture") as MeshInstance3D
	if visual == null:
		return
	# Keep only a visual remnant; the full-size physics body expires immediately.
	visual.reparent(_burning_block.get_parent(), true)
	visual.name = "BurnCollapse"
	var tween := visual.create_tween().set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ONE * 0.001, BURN_COLLAPSE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	for child in visual.get_children():
		if child is MultiMeshInstance3D and "visual_fade" in child:
			tween.tween_property(child, "visual_fade", 0.0, BURN_COLLAPSE_DURATION)
	tween.chain().tween_callback(visual.queue_free)

func _update_burn_label() -> void:
	if _burn_label == null:
		return
	_burn_label.visible = burn_timer_enabled
	_burn_label.text = "已燃尽" if burn_remaining <= 0.0 else "燃尽倒计时 %.2fs" % burn_remaining
	var counting := is_instance_valid(_burning_block) and not _burning_block.is_queued_for_deletion()
	_burn_label.modulate = Color("ff4545") if counting or burn_remaining <= 0.0 else Color("ffda63")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		if burn_remaining <= 0.0:
			get_viewport().set_input_as_handled()
			return
		if _mode == "":
			_mode = "armed"
			_has_target = false
		elif _mode == "armed":
			_cancel_mode()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and _mode == "armed":
		_update_target_at(event.position)
		return
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return
	if _player == null or _cube == null or _blocks_root == null:
		return
	if _mode != "armed":
		return
	var picked := _pick_mouse(event.position)
	if picked.get("block") != null:
		get_viewport().set_input_as_handled()
		_selected_block = picked["block"] as Node3D
		_confirm_remove()
	elif picked.has("position"):
		get_viewport().set_input_as_handled()
		_selected_block = null
		_target = picked["position"]
		_confirm_place()


func _update_target_at(screen_pos: Vector2) -> void:
	var picked := _pick_mouse(screen_pos)
	_hover_block = picked.get("block") as Node3D
	if _hover_block != null:
		_preview.global_position = _hover_block.global_position
		_preview.visible = true
		_preview_material.albedo_color = Color(1.0, 0.45, 0.3, 0.65)
		_has_target = true
	elif picked.has("position"):
		_target = picked["position"]
		_preview.position = _target
		_preview.visible = true
		_preview_material.albedo_color = Color(1.0, 0.8, 0.15, 0.48) if _available > 0 and not _occupied(_target) else Color(1.0, 0.35, 0.3, 0.55)
		_has_target = true
	else:
		_preview.visible = false
		_has_target = false


func _pick_mouse(screen_pos: Vector2) -> Dictionary:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos).normalized()
	var nearest_t := INF
	var nearest_block: Node3D
	for child in _blocks_root.get_children():
		if child is not Node3D or not String(child.name).begins_with("PlayerBlock"):
			continue
		var block := child as Node3D
		var to_block := block.global_position - origin
		var t := to_block.dot(direction)
		if t > 0.0 and t < nearest_t and (origin + direction * t).distance_to(block.global_position) <= 0.95:
			nearest_t = t
			nearest_block = block
	if nearest_block != null:
		return {"block": nearest_block}

	var best_t := INF
	var best_target := Vector3.ZERO
	if _walls_root == null:
		return {}
	for face in _walls_root.get_children():
		if not (face is Node3D):
			continue
		var face_node := face as Node3D
		var mesh := face_node.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh != null and not mesh.visible:
			continue
		var normal := face_node.global_basis.y.normalized()
		var denominator := direction.dot(normal)
		if absf(denominator) < 0.0001:
			continue
		var t := (face_node.global_position - origin).dot(normal) / denominator
		if t <= 0.0 or t >= best_t:
			continue
		var hit_local := face_node.to_local(origin + direction * t)
		if absf(hit_local.x) > wall_half_extent or absf(hit_local.z) > wall_half_extent:
			continue
		var cell_limit := wall_half_extent - 0.5
		var gx := clampf(roundf(hit_local.x - 0.5) + 0.5, -cell_limit, cell_limit)
		var gz := clampf(roundf(hit_local.z - 0.5) + 0.5, -cell_limit, cell_limit)
		var snapped_local := Vector3(gx, 0.5, gz)
		best_t = t
		best_target = _cube.to_local(face_node.to_global(snapped_local))
	if best_t == INF:
		return {}
	return {"position": best_target}


func _occupied(pos: Vector3) -> bool:
	for child in _blocks_root.get_children():
		if child is Node3D and (child.name.begins_with("PlayerBlock") or child.name.begins_with("StaticBox")):
			if (child as Node3D).position.distance_to(pos) < 0.1:
				return true
	return false


func _confirm_place() -> void:
	if burn_remaining <= 0.0 or _available <= 0 or _occupied(_target):
		return
	var block := BLOCK_SCENE.instantiate() as Node3D
	block.name = "PlayerBlock"
	_blocks_root.add_child(block)
	block.position = _target
	_burning_block = block
	_update_burn_visual.call_deferred()
	_apply_player_block_color(block)
	_available -= 1
	_has_target = false
	if _cube.has_method("update_cutaway_visibility"):
		_cube.update_cutaway_visibility()


func _confirm_remove() -> void:
	if is_instance_valid(_selected_block):
		if _selected_block == _burning_block:
			_burning_block = null
		_selected_block.queue_free()
		_available = mini(_available + 1, 1) if burn_remaining > 0.0 else 0
	_selected_block = null
	_has_target = false


func _cancel_mode() -> void:
	_mode = ""
	_selected_block = null
	_hover_block = null
	_has_target = false
	_preview.visible = false


func _apply_player_block_color(node: Node) -> void:
	if node is MeshInstance3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.9, 0.28, 1.0)
		mat.roughness = 0.35
		mat.emission_enabled = true
		mat.emission = Color(0.05, 0.25, 0.04, 1.0)
		(node as MeshInstance3D).material_override = mat
	for child in node.get_children():
		_apply_player_block_color(child)
