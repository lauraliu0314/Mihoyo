extends Node3D
## 教学关放置引导。把子节点「提示格子1」「提示格子2」拖到目标格子附近。
## 先亮第 1 个，玩家把方块放上之后再亮第 2 个。位置会吸附到最近的格子中心。

const XZ_MIN := -2.5
const XZ_MAX := 2.5
const Y_MIN := 0.5
const Y_MAX := 5.5

var _cube: Node3D
var _markers: Array[Marker3D] = []
var _done: Array[bool] = []
var _highlight: MeshInstance3D


func _ready() -> void:
	_cube = get_parent() as Node3D
	for child in get_children():
		if child is Marker3D:
			var marker := child as Marker3D
			marker.gizmo_extents = 0.55
			_markers.append(marker)
			_done.append(false)
	_build_highlight()


func _process(_delta: float) -> void:
	if _cube == null or _highlight == null:
		return
	_refresh_done()
	var step := _current_step()
	if step < 0:
		_highlight.visible = false
		return
	var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)
	_highlight.visible = true
	_highlight.position = _marker_cell(_markers[step])
	_highlight.scale = Vector3.ONE * lerpf(0.62, 1.0, pulse)


func _current_step() -> int:
	for i in _markers.size():
		if not _done[i]:
			return i
	return -1


func _refresh_done() -> void:
	for i in _markers.size():
		if _done[i]:
			continue
		if _placed_at(_marker_cell(_markers[i])):
			_done[i] = true


func _marker_cell(marker: Marker3D) -> Vector3:
	var local := _cube.to_local(marker.global_position)
	return Vector3(
		_snap_center(local.x, XZ_MIN, XZ_MAX),
		_snap_center(local.y, Y_MIN, Y_MAX),
		_snap_center(local.z, XZ_MIN, XZ_MAX)
	)


func _placed_at(cell: Vector3) -> bool:
	var root := _cube.get_node_or_null("staticboxes")
	if root == null:
		return false
	for child in root.get_children():
		if not (child is Node3D):
			continue
		if not String(child.name).begins_with("StaticBoxPlaced"):
			continue
		if (child as Node3D).position.distance_to(cell) < 0.45:
			return true
	return false


func _build_highlight() -> void:
	var block_size: float = preload("res://assets/decon/decon_style.gd").load_default().visual_scale()
	_highlight = MeshInstance3D.new()
	_highlight.name = "GuideHighlight"
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE * block_size
	_highlight.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.86, 0.1, 0.38)
	_highlight.material_override = mat
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)


func _snap_center(value: float, low: float, high: float) -> float:
	var snapped := roundf(value - 0.5) + 0.5
	return clampf(snapped, low, high)
