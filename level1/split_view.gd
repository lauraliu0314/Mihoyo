extends Control

## Split-screen mirror: the left half plays, the right half copies the room cube
## and the falling rigid props.

## Full window framed the room with an ortho height of 10 at 16:9.
## Each split panel is only half as wide, so keep that same view width
## or the room cube fills the panel. UI stays in screen space.
const _SPLIT_CAMERA_WIDTH := 10.0 * 1920.0 / 1080.0

@onready var _left_viewport: SubViewport = $HBox/LeftContainer/LeftViewport
@onready var _right_viewport: SubViewport = $HBox/RightContainer/RightViewport
@onready var _left_cube: Node3D = $HBox/LeftContainer/LeftViewport/Main/Node3D
@onready var _right_cube: Node3D = $HBox/RightContainer/RightViewport/Main/Node3D

var _prop_pairs: Array[Dictionary] = []


func _ready() -> void:
	# After the flip tween, so this frame's pose is the one we copy.
	process_priority = 100
	_fit_split_cameras()
	_prepare_mirror($HBox/RightContainer/RightViewport/Main)
	_collect_prop_pairs(_left_cube, _right_cube)


func _fit_split_cameras() -> void:
	for viewport in [_left_viewport, _right_viewport]:
		var cam := viewport.find_child("Camera3D", true, false) as Camera3D
		if cam == null:
			continue
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.size = _SPLIT_CAMERA_WIDTH


func _prepare_mirror(mirror: Node) -> void:
	var player := mirror.get_node_or_null("Player")
	if player != null:
		player.remove_from_group("player")
		player.process_mode = Node.PROCESS_MODE_DISABLED
		player.visible = false
		if player is CollisionObject3D:
			var body := player as CollisionObject3D
			body.collision_layer = 0
			body.collision_mask = 0

	var ui := mirror.get_node_or_null("ui_ingame")
	if ui != null:
		ui.remove_from_group("ui_ingame")
		ui.process_mode = Node.PROCESS_MODE_DISABLED
		if "visible" in ui:
			ui.visible = false

	if _right_cube != null:
		# Cutaway unfreezes visible props unless this hold stays on.
		_right_cube.set("_hold_props_frozen", true)
	_freeze_bodies(mirror)
	_mute_audio(mirror)


func _freeze_bodies(node: Node) -> void:
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	for child in node.get_children():
		_freeze_bodies(child)


func _mute_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		var stream_player := node as AudioStreamPlayer
		stream_player.stop()
		stream_player.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is AudioStreamPlayer2D:
		var stream_player_2d := node as AudioStreamPlayer2D
		stream_player_2d.stop()
		stream_player_2d.process_mode = Node.PROCESS_MODE_DISABLED
	elif node is AudioStreamPlayer3D:
		var stream_player_3d := node as AudioStreamPlayer3D
		stream_player_3d.stop()
		stream_player_3d.process_mode = Node.PROCESS_MODE_DISABLED
	for child in node.get_children():
		_mute_audio(child)


func _collect_prop_pairs(left: Node, right: Node) -> void:
	if left is RigidBody3D and right is RigidBody3D:
		var body := right as RigidBody3D
		body.freeze = true
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		# The left body simulates the fall. The right one only plays that pose.
		body.process_mode = Node.PROCESS_MODE_DISABLED
		_prop_pairs.append({"src": left, "dst": right})
	var dst_by_name := {}
	for child in right.get_children():
		dst_by_name[String(child.name)] = child
	for child in left.get_children():
		var key := String(child.name)
		if not dst_by_name.has(key):
			continue
		_collect_prop_pairs(child, dst_by_name[key])


func _process(_delta: float) -> void:
	if not is_inside_tree():
		return
	if not is_instance_valid(_left_cube) or not is_instance_valid(_right_cube):
		return
	_right_cube.set("_hold_props_frozen", true)
	_right_cube.global_transform = _left_cube.global_transform
	_sync_prop_transforms()
	if _right_cube.has_method("update_cutaway_visibility"):
		_right_cube.update_cutaway_visibility()
	_sync_prop_visibility()


func _sync_prop_transforms() -> void:
	if not is_inside_tree():
		return
	var alive: Array[Dictionary] = []
	for pair in _prop_pairs:
		var src_ref = pair["src"]
		var dst_ref = pair["dst"]
		# Typed assignment of a freed object aborts the running game.
		if not is_instance_valid(src_ref) or not is_instance_valid(dst_ref):
			if is_instance_valid(dst_ref) and dst_ref is Node3D:
				(dst_ref as Node3D).visible = false
			continue
		if not (src_ref is Node3D and dst_ref is Node3D):
			continue
		alive.append(pair)
		var src_3d := src_ref as Node3D
		var dst_3d := dst_ref as Node3D
		dst_3d.top_level = src_3d.top_level
		if src_3d.top_level:
			dst_3d.global_transform = src_3d.global_transform
		else:
			dst_3d.transform = src_3d.transform
		_copy_child_transforms(src_3d, dst_3d)
	_prop_pairs = alive


func _copy_child_transforms(src: Node, dst: Node) -> void:
	if not is_instance_valid(src) or not is_instance_valid(dst):
		return
	var dst_by_name := {}
	for child in dst.get_children():
		if not is_instance_valid(child):
			continue
		dst_by_name[String(child.name)] = child
	for child in src.get_children():
		if not is_instance_valid(child):
			continue
		var key := String(child.name)
		if not dst_by_name.has(key):
			continue
		var other = dst_by_name[key]
		if not is_instance_valid(other):
			continue
		if child is RigidBody3D or not (child is Node3D and other is Node3D):
			continue
		var src_3d := child as Node3D
		var dst_3d := other as Node3D
		dst_3d.top_level = src_3d.top_level
		if src_3d.top_level:
			dst_3d.global_transform = src_3d.global_transform
		else:
			dst_3d.transform = src_3d.transform
		_copy_child_transforms(src_3d, dst_3d)


func _sync_prop_visibility() -> void:
	if not is_inside_tree():
		return
	for pair in _prop_pairs:
		var src_ref = pair["src"]
		var dst_ref = pair["dst"]
		if not is_instance_valid(dst_ref) or not (dst_ref is Node3D):
			continue
		if not is_instance_valid(src_ref) or not (src_ref is Node):
			(dst_ref as Node3D).visible = false
			continue
		_copy_visible(src_ref as Node, dst_ref as Node)


func _copy_visible(src: Node, dst: Node) -> void:
	if not is_instance_valid(src) or not is_instance_valid(dst):
		return
	if "visible" in src and "visible" in dst:
		dst.visible = src.visible
	var dst_by_name := {}
	for child in dst.get_children():
		if is_instance_valid(child):
			dst_by_name[String(child.name)] = child
	for child in src.get_children():
		if not is_instance_valid(child):
			continue
		var key := String(child.name)
		if not dst_by_name.has(key) or not is_instance_valid(dst_by_name[key]):
			continue
		if not (child is Node and dst_by_name[key] is Node):
			continue
		_copy_visible(child as Node, dst_by_name[key] as Node)


func _exit_tree() -> void:
	_prop_pairs.clear()


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard is delivered to the root viewport, not the playable SubViewport.
	if not is_inside_tree() or not (event is InputEventKey):
		return
	if not is_instance_valid(_left_viewport) or not _left_viewport.is_inside_tree():
		return
	_left_viewport.push_input(event)
