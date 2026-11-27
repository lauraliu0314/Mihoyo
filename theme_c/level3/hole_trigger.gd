extends Area3D

@export_range(0.2, 2.0, 0.05) var fall_duration := 0.7
@export_range(0.5, 4.0, 0.1) var fall_distance := 2.4

var _triggered := false


func _ready() -> void:
	monitoring = true
	body_entered.connect(_try_fall)


func _physics_process(_delta: float) -> void:
	if _triggered or global_basis.z.normalized().dot(Vector3.UP) < 0.82:
		return
	for body in get_overlapping_bodies():
		_try_fall(body)


func _try_fall(body: Node3D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	if global_basis.z.normalized().dot(Vector3.UP) < 0.82:
		return
	if body.get("is_dead") == true:
		return
	# Trigger only when the player center is inside the opening.
	var local_body := to_local(body.global_position)
	if absf(local_body.x) > 0.22 or absf(local_body.y) > 0.22:
		return
	_triggered = true
	var roll := body.get_node_or_null("RollController")
	if roll != null and roll.has_method("cancel"):
		roll.call("cancel")
	var jump := body.get_node_or_null("JumpController")
	if jump != null and jump.has_method("cancel"):
		jump.call("cancel")
	body.set_physics_process(false)
	body.set_process_input(false)
	body.set_process_unhandled_input(false)
	body.collision_layer = 0
	body.collision_mask = 0
	var opening_center := global_position - global_basis.z.normalized() * 0.35
	var centered := opening_center + Vector3.UP * 0.45
	var tween := create_tween()
	tween.tween_property(body, "global_position", centered, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "global_position", centered + Vector3.DOWN * fall_distance, fall_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	if is_instance_valid(body) and body.has_method("die"):
		body.call("die")
