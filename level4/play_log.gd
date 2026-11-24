extends Node

## 第四关试玩记录。只写操作和 pizza / 玩家状态，方便看卡住的那一下。

const LOG_PATH := "res://level4_playlog.txt"
const HOLE_LOCAL := Vector3(-3.5, 3.5, 0.5)
const ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right",
	"jump", "rotate_left", "rotate_right",
]

var _file: FileAccess
var _cube: Node3D
var _player: CharacterBody3D
var _pizza: RigidBody3D
var _elapsed := 0.0
var _sample_t := 0.0
var _held: Dictionary = {}


func _ready() -> void:
	_file = FileAccess.open(ProjectSettings.globalize_path(LOG_PATH), FileAccess.WRITE)
	_cube = get_parent().get_node_or_null("Node3D") as Node3D
	_player = get_parent().get_node_or_null("Player") as CharacterBody3D
	if _cube != null:
		_pizza = _cube.get_node_or_null("MovableBox_C") as RigidBody3D
	_log("session start hole_local=%s" % HOLE_LOCAL)
	_log_state("init")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_log("key %s" % OS.get_keycode_string(event.physical_keycode))
	elif event is InputEventMouseButton and event.pressed:
		_log("mouse btn=%s at=%s" % [event.button_index, event.position])


func _physics_process(delta: float) -> void:
	_elapsed += delta
	for action in ACTIONS:
		var down := Input.is_action_pressed(action)
		if down != bool(_held.get(action, false)):
			_held[action] = down
			_log("action %s %s" % [action, "down" if down else "up"])
			_log_state("input")
	_sample_t += delta
	if _sample_t < 0.4:
		return
	_sample_t = 0.0
	_log_state("tick")


func _log_state(tag: String) -> void:
	var player_local := Vector3.INF
	var player_vel := Vector3.ZERO
	var on_floor := false
	if _player != null and _cube != null:
		player_local = _cube.to_local(_player.global_position)
		player_vel = _player.velocity
		on_floor = _player.is_on_floor()
	var pizza_local := Vector3.INF
	var pizza_vel := Vector3.ZERO
	var shape_local := Vector3.INF
	var freeze := false
	var sleeping := false
	var gravity := 0.0
	var falling := false
	var fallen := false
	var contacts := ""
	var hole_dist := -1.0
	if _pizza != null and is_instance_valid(_pizza):
		pizza_local = _pizza.position
		pizza_vel = _pizza.linear_velocity
		freeze = _pizza.freeze
		sleeping = _pizza.sleeping
		gravity = _pizza.gravity_scale
		falling = bool(_pizza.get("ceiling_falling"))
		fallen = bool(_pizza.get("_has_fallen_from_ceiling"))
		hole_dist = pizza_local.distance_to(HOLE_LOCAL)
		var shape := _pizza.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if shape != null and _cube != null:
			shape_local = _cube.to_local(shape.global_position)
		var names: PackedStringArray = []
		for body in _pizza.get_colliding_bodies():
			if body is Node:
				names.append((body as Node).name)
		contacts = ",".join(names)
	_log(
		"%s player=%s floor=%s pvel=%s pizza=%s shape=%s hole_dist=%.2f vel=%s freeze=%s sleep=%s grav=%.1f falling=%s fallen=%s contacts=[%s]"
		% [
			tag,
			_fmt(player_local),
			on_floor,
			_fmt(player_vel),
			_fmt(pizza_local),
			_fmt(shape_local),
			hole_dist,
			_fmt(pizza_vel),
			freeze,
			sleeping,
			gravity,
			falling,
			fallen,
			contacts,
		]
	)


func _log(message: String) -> void:
	var line := "[PlayLog t=%.2f] %s" % [_elapsed, message]
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()


func _fmt(v: Vector3) -> String:
	if not v.is_finite():
		return "?"
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]
