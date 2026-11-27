extends Node3D
## MarkerFace and arrow meshes are editable children in level2/main.tscn.
## Rotate this node to orient its surface and the allowed drag direction.

@export var half_size: float = 0.43
@export var host_sticker_path: NodePath

var _host_sticker: Node3D
var _host_offset: Transform3D


func _ready() -> void:
	add_to_group("rubik_turn_marker")
	if not host_sticker_path.is_empty():
		_host_sticker = get_node_or_null(host_sticker_path) as Node3D
		if _host_sticker != null:
			_host_offset = _host_sticker.global_transform.affine_inverse() * global_transform


func _process(_delta: float) -> void:
	if _host_sticker != null:
		global_transform = _host_sticker.global_transform * _host_offset
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		visible = is_facing_camera(camera)


func is_facing_camera(camera: Camera3D) -> bool:
	if _host_sticker != null and not _host_sticker.visible:
		return false
	return global_basis.z.normalized().dot((camera.global_position - global_position).normalized()) > 0.08


func get_turn_axis(cube: Node3D) -> Vector3:
	# The arrow lies along local Y. Dragging along it rotates about local X.
	# Deriving the axis from the transform keeps artwork and gameplay aligned
	# when a designer rotates a marker in the scene editor.
	return (cube.global_basis.inverse() * global_basis.x).normalized()


func pick_from_mouse(camera: Camera3D, mouse: Vector2) -> Dictionary:
	if not is_facing_camera(camera):
		return {}
	var ray_origin := camera.project_ray_origin(mouse)
	var ray_direction := camera.project_ray_normal(mouse)
	var local_origin := to_local(ray_origin)
	var local_direction := (global_basis.inverse() * ray_direction).normalized()
	if absf(local_direction.z) < 0.0001:
		return {}
	var distance := -local_origin.z / local_direction.z
	if distance <= 0.0:
		return {}
	var hit := local_origin + local_direction * distance
	if absf(hit.x) > half_size or absf(hit.y) > half_size:
		return {}
	var world_point := to_global(Vector3(hit.x, hit.y, 0.0))
	return {"point": world_point, "normal": global_basis.z.normalized(), "distance": ray_origin.distance_to(world_point)}


