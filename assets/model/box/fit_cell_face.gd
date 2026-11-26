extends Node3D
## Snaps the exit square onto the grid face it already sits on.

@onready var _vortex: MeshInstance3D = $Vortex


func _ready() -> void:
	call_deferred("_fit_cell")


func _fit_cell() -> void:
	if _vortex == null or not is_inside_tree():
		return
	var cube := _cube_root()
	if cube == null:
		return
	var cube_xform := cube.global_transform
	var center: Vector3 = cube_xform.affine_inverse() * _vortex.global_position
	var normal: Vector3 = cube_xform.basis.inverse() * _vortex.global_transform.basis.y
	if normal.length_squared() < 0.0001:
		return
	normal = normal.normalized()
	var axis := 0
	var best := 0.0
	for i in 3:
		var mag := absf(normal[i])
		if mag > best:
			best = mag
			axis = i
	var facing := 1.0 if normal[axis] >= 0.0 else -1.0
	var snapped := Vector3.ZERO
	for i in 3:
		if i == axis:
			snapped[i] = roundf(center[i]) + facing * 0.01
		else:
			snapped[i] = roundf(center[i] - 0.5) + 0.5
	var y := Vector3.ZERO
	y[axis] = facing
	var x_index := 0 if axis != 0 else 1
	var x := Vector3.ZERO
	x[x_index] = 1.0
	var square_scale := _vortex.transform.basis.get_scale()
	var square := Transform3D(Basis(x, y, x.cross(y)).scaled(square_scale), snapped)
	global_transform = cube_xform * square * _vortex.transform.affine_inverse()


func _cube_root() -> Node3D:
	var scene := get_tree().current_scene
	var node: Node = get_parent()
	var cube: Node3D = null
	while node != null and node != scene:
		cube = node as Node3D
		node = node.get_parent()
	if cube != null:
		return cube
	return scene as Node3D
