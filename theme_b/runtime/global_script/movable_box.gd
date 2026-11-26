extends RigidBody3D

## 可移动道具：天花板上保持固定，其他面沿用普通重力与裁切。
## 保留旧导出字段以兼容关卡资源；不再触发天花板特殊下落。
@export var fall_when_on_ceiling := false

@export_group("碰撞体积")
## 勾选后，开局用下面的尺寸覆盖碰撞盒，并把碰撞盒居中。第五关用这个改体积；第六关保持场景里的碰撞。
@export var override_collision_size := false
## 碰撞盒尺寸（米）。三项相同就是正方体，平放和竖着的绑墙、掉落一样。
@export var collision_size := Vector3(0.8, 0.3, 0.8)

## 认为已经「开始掉落」的向下速度阈值。
const FALL_SPEED := 0.35
## 落地停稳速度阈值。
const SETTLE_SPEED := 0.12
## 停稳后连续多少物理帧才允许判死（避免下落途中短暂减速误判）。
const SETTLE_FRAMES_REQUIRED := 8
## 砸中判定：水平中心距上限。旁落/擦边不算压在箱子上。
const LAND_LATERAL_MAX := 0.4
## 砸中判定：相对 StaticBox，箱子中心至少高出这么多（世界 Y）。
const LAND_MIN_ABOVE := 0.55
## 砸中判定：相对 StaticBox，箱子中心最多高出这么多（一格叠放约 1）。
const LAND_MAX_ABOVE := 1.25

var start_transform: Transform3D
var ceiling_falling := false
var _fail_triggered := false
## 已离开天花板并产生过明显下落，才允许判定砸到 StaticBox。
var _has_fallen_from_ceiling := false
var _settle_frames := 0
## 记录开局的 fall_when_on_ceiling，reset 时恢复。
var _fall_when_on_ceiling_default := false


func _ready() -> void:
	start_transform = transform
	_fall_when_on_ceiling_default = fall_when_on_ceiling
	if override_collision_size:
		_apply_collision_size()
	if fall_when_on_ceiling:
		lock_rotation = true
		gravity_scale = 1.0
		contact_monitor = true
		max_contacts_reported = 8
		continuous_cd = true
		set_physics_process(true)
	else:
		set_physics_process(false)


## 正方体/扁平碰撞贴在所在那一面内侧，留出一点空隙，避免贴死墙皮后下落时被挤偏。
const FACE_CLEARANCE := 0.03
var _seated_basis := Basis()
var _collision_seated := false


func _apply_collision_size() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null or not (shape_node.shape is BoxShape3D):
		return
	var box := (shape_node.shape as BoxShape3D).duplicate() as BoxShape3D
	box.size = collision_size
	box.margin = 0.01
	shape_node.shape = box
	_collision_seated = false
	_seat_collision_on_face()


## 碰撞中心沿格子朝墙的方向收在面内侧，不跟着披萨模型的平放/竖放转到格子外面。
func _seat_collision_on_face() -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return
	if _collision_seated and basis.is_equal_approx(_seated_basis):
		return
	var half_extent := collision_size.y * 0.5
	var sink := maxf(0.5 - half_extent - FACE_CLEARANCE, 0.0)
	shape_node.position = basis.inverse() * Vector3(0.0, -sink, 0.0)
	shape_node.basis = basis.inverse()
	_seated_basis = basis
	_collision_seated = true


## 擦到隔壁冰块的棱才算卡住：重叠只有薄薄一层。整面撞上或压在箱子上不动。
const LIP_OVERLAP := 0.12


## 0.6 的碰撞贴着格子边界时，会多出一两厘米，滑向旁边的空格会被上一格冰块的棱挡住。
## 重力方向上的接触保留（那是真的落地或撞墙）；只把侧向的薄重叠推回空格里。
func _separate_from_cell_lips(cube: Node3D) -> void:
	var shape_node := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var boxes := cube.get_node_or_null("staticboxes")
	if shape_node == null or boxes == null:
		return
	var center := cube.to_local(shape_node.global_position)
	var half := collision_size * 0.5
	var grav := cube.global_transform.basis.inverse() * Vector3.DOWN
	var grav_axis := _dominant_axis(grav)
	var best_push := Vector3.ZERO
	var best_depth := 0.0
	for box in boxes.get_children():
		if not (box is Node3D) or not is_instance_valid(box):
			continue
		var box_pos := cube.to_local((box as Node3D).global_position)
		var delta := center - box_pos
		var overlap := Vector3(
			half.x + 0.5 - absf(delta.x),
			half.y + 0.5 - absf(delta.y),
			half.z + 0.5 - absf(delta.z)
		)
		if overlap.x <= 0.0 or overlap.y <= 0.0 or overlap.z <= 0.0:
			continue
		var axis := -1
		var depth := LIP_OVERLAP
		for i in 3:
			if i == grav_axis:
				continue
			var axis_overlap: float = overlap[i]
			if axis_overlap < depth:
				depth = axis_overlap
				axis = i
		if axis < 0:
			continue
		var push_mag := depth + FACE_CLEARANCE
		if push_mag <= best_depth:
			continue
		var push := Vector3.ZERO
		push[axis] = (-1.0 if delta[axis] < 0.0 else 1.0) * push_mag
		best_depth = push_mag
		best_push = push
	if best_push == Vector3.ZERO:
		return
	position += best_push
	sleeping = false
	print("[PlayLog] unstick pizza by %s off cell lip" % best_push)


func _dominant_axis(v: Vector3) -> int:
	var axis := 0
	var best := absf(v.x)
	if absf(v.y) > best:
		axis = 1
		best = absf(v.y)
	if absf(v.z) > best:
		axis = 2
	return axis


func _physics_process(_delta: float) -> void:
	if override_collision_size:
		_seat_collision_on_face()
	if is_locked_as_static():
		return
	var cube := _find_cube_world()
	if _is_ceiling_only_for_fall():
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true
		return
	if cube != null and override_collision_size and not freeze:
		_separate_from_cell_lips(cube)

func reset_to_start() -> void:
	if has_meta("locked_as_static"):
		remove_meta("locked_as_static")
	fall_when_on_ceiling = _fall_when_on_ceiling_default
	ceiling_falling = false
	_fail_triggered = false
	_has_fallen_from_ceiling = false
	_settle_frames = 0
	gravity_scale = 1.0 if fall_when_on_ceiling else 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	transform = start_transform
	freeze = false
	set_physics_process(fall_when_on_ceiling)
	if fall_when_on_ceiling:
		sleeping = true


func is_blocking_cube_motion() -> bool:
	return false

func lock_as_static() -> void:
	if is_locked_as_static():
		return
	set_meta("locked_as_static", true)
	fall_when_on_ceiling = false
	ceiling_falling = false
	_has_fallen_from_ceiling = false
	_fail_triggered = false
	_settle_frames = 0
	gravity_scale = 0.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	sleeping = true
	set_physics_process(false)
	# 保证碰撞可用；显隐交给裁切。
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = false
	var cube := _find_cube_world()
	if cube != null and cube.has_method("mark_prop_fixed_like_static"):
		cube.mark_prop_fixed_like_static(self)


func is_locked_as_static() -> bool:
	return has_meta("locked_as_static") and bool(get_meta("locked_as_static"))


## 由 cube_world 裁切刷新调用。
## 返回 true：本帧自管显隐（只绑天花板 / 已真正下落中）。
## 返回 false：走普通随墙显隐。
## 注意：下落用更严的绑墙判定，不能直接用裁切传入的 bound_walls（容差 0.25 会把贴边误判成天花板+侧墙）。
func sync_ceiling_fall(_bound_walls: Array, _hold_frozen: bool) -> bool:
	# Compatibility entry point for all cube_world versions: no special fall.
	return false

func apply_cutaway_visibility(wall_visible: bool) -> void:
	visible = wall_visible
	for child in get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", not wall_visible)
	var cube := _find_cube_world()
	var hold := cube != null and bool(cube.get("_hold_props_frozen"))
	var captured := bool(get_meta("locked_in_e1", false))
	if is_locked_as_static() or captured or hold or not wall_visible or _is_ceiling_only_for_fall():
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
		freeze = true
	elif not get_tree().paused:
		freeze = false
		sleeping = false



func _is_ceiling_only_for_fall() -> bool:
	return _is_ceiling_only_bound(_fall_bind_walls())


func _fall_bind_walls() -> Array:
	var cube := _find_cube_world()
	if cube == null:
		return []
	if cube.has_method("get_nearest_walls_for_fall"):
		return cube.get_nearest_walls_for_fall(self)
	if cube.has_method("get_nearest_walls_for"):
		return cube.get_nearest_walls_for(self)
	return []


func _has_floor_support_for_fall() -> bool:
	for item in _fall_bind_walls():
		var wall := item as Node3D
		if wall != null and is_instance_valid(wall) and _wall_is_floor(wall):
			return true
	return false




func _exit_ceiling_fall_mode() -> void:
	ceiling_falling = false
	_has_fallen_from_ceiling = false
	_settle_frames = 0
	gravity_scale = 1.0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


func _contacting_staticbox() -> bool:
	for collider in get_colliding_bodies():
		var static_box := _find_static_box_root(collider)
		if static_box != null and _is_resting_on_top_of(static_box):
			return true
	return false


## 必须大致叠在 StaticBox 正上方才算砸中；侧碰/掉旁边不算。
func _is_resting_on_top_of(static_box: Node3D) -> bool:
	var my_pos := _collision_center(self)
	var box_pos := _collision_center(static_box)
	var offset := my_pos - box_pos
	var lateral := Vector3(offset.x, 0.0, offset.z)
	if lateral.length() > LAND_LATERAL_MAX:
		return false
	if offset.y < LAND_MIN_ABOVE or offset.y > LAND_MAX_ABOVE:
		return false
	return true


func _collision_center(body: Node3D) -> Vector3:
	for child in body.get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			return (child as CollisionShape3D).global_position
	return body.global_position


func _find_static_box_root(node: Node) -> Node3D:
	var n: Node = node
	while n != null:
		var name_str := String(n.name)
		if "StaticBox" in name_str and "MovableBox" not in name_str and n is Node3D:
			# 披萨盒（E1/E2）是机关，不是致命落点。
			if "StaticBox_E" in name_str or "EXIT" in name_str:
				return null
			return n as Node3D
		n = n.get_parent()
	return null


func _is_static_box(node: Node) -> bool:
	return _find_static_box_root(node) != null


func _trigger_fail_on_staticbox() -> void:
	if _fail_triggered:
		return
	_fail_triggered = true
	ceiling_falling = false
	_has_fallen_from_ceiling = false
	_settle_frames = 0
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true

	var player := _find_player()
	if player == null or not player.has_method("die"):
		push_warning("MovableBox: landed on StaticBox but Player.die() not found")
		return
	# 只有玩家在落点附近才死亡；走到远处的披萨盒不会被远端落箱误杀。
	if player.global_position.distance_to(global_position) > 1.35:
		return
	player.call_deferred("die")


func _force_visible_solid() -> void:
	visible = true
	for child in get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = false


## 绑定面里只有天花板（不含侧墙/地板）时才启用掉落规则。
func _is_ceiling_only_bound(bound_walls: Array) -> bool:
	if bound_walls.is_empty():
		return false
	var has_ceiling := false
	for item in bound_walls:
		var wall := item as Node3D
		if wall == null or not is_instance_valid(wall):
			continue
		if _wall_is_ceiling(wall):
			has_ceiling = true
		else:
			return false
	return has_ceiling


func _wall_is_ceiling(wall: Node3D) -> bool:
	var outward := -wall.global_transform.basis.y.normalized()
	return outward.y > 0.7


func _wall_is_floor(wall: Node3D) -> bool:
	var outward := -wall.global_transform.basis.y.normalized()
	return outward.y < -0.7


func _is_nearly_settled() -> bool:
	# 不要把 freeze 当成落稳：翻转 hold 时也会 freeze，会误判死。
	return linear_velocity.length() <= SETTLE_SPEED and angular_velocity.length() <= SETTLE_SPEED


func _find_cube_world() -> Node:
	var n: Node = self
	while n != null:
		if n.has_method("update_cutaway_visibility"):
			return n
		n = n.get_parent()
	return null


func _find_player() -> Node:
	var cube := _find_cube_world()
	if cube == null:
		return null
	var host := cube.get_parent()
	if host == null:
		return null
	return host.get_node_or_null("Player")
