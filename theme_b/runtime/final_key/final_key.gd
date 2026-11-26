@tool
extends Node3D

## 终局钥匙 + 终点大门。
## 玩家吃掉钥匙后大门激活；进入 1×1×1 终点区域即通关。
## 节点名含 Final_，会随附着墙面裁切显隐。


@export var key_position := Vector3(0.0, 0.25, 0.0)
@export var exit_position := Vector3(2.0, 0.5, 0.0)
@export var require_pizza_capture := false
@export var capture_source_path: NodePath = ^"../Tool_B_D_G/G_Tool"
var _capture_complete := false



@onready var final_key: Area3D = $Final_Key
@onready var final_exit: Area3D = $Final_Exit

var exit_unlocked := false


func _ready() -> void:
	_apply_positions()
	if Engine.is_editor_hint():
		set_process(true)
		return

	if require_pizza_capture:
		_ensure_notice_ui.call_deferred()
		var source := get_node_or_null(capture_source_path)
		if source != null and source.has_signal("g_collected"):
			source.connect("g_collected", _on_pizza_captured)
		else:
			push_error("FinalKey: capture source missing; button remains locked")

	if final_key and final_key.has_method("setup"):
		final_key.setup(self)
	if final_exit and final_exit.has_method("setup"):
		final_exit.setup(self)

	# 场景初始状态必须和 exit_unlocked 一致。
	if final_exit and final_exit.has_method("set_active"):
		final_exit.set_active(exit_unlocked)

	_refresh_exit_look()
	set_process(false)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_positions()


func _apply_positions() -> void:
	if final_key:
		final_key.position = key_position
	if final_exit:
		final_exit.position = exit_position


func unlock_exit() -> void:
	if exit_unlocked or not can_press_button():
		return

	exit_unlocked = true
	_refresh_exit_look()

	if final_exit and final_exit.has_method("set_active"):
		final_exit.set_active(true)

	_show_exit_unlocked_notice()


func can_press_button() -> bool:
	return not require_pizza_capture or _capture_complete

func _on_pizza_captured() -> void:
	_capture_complete = true
	if final_key != null:
		final_key.call_deferred("_check_initial_overlaps")

func _ensure_notice_ui() -> void:
	if get_tree().get_first_node_in_group("notice_manager") != null:
		return
	# Reuse the existing notice panel and its exact styling/animation.
	var template: Node = load("res://theme_b/runtime/assets/ui/ui_ingame_shared.tscn").instantiate()
	var notices := template.get_node("Notices")
	template.remove_child(notices)
	template.free()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(notices)
func can_win() -> bool:
	return exit_unlocked


func trigger_win(player: Node) -> void:
	if not can_win():
		return

	var ui := _find_ui_ingame()

	if ui == null:
		push_warning("Final_Key: 找不到 ui_ingame，无法通关")
		return

	# 锅的吸入动画结束后才会进入这里。
	if ui.has_method("show_win_after_absorb"):
		ui.show_win_after_absorb()
	elif ui.has_method("_show_win"):
		ui._show_win()
	elif (
		ui.has_method("_on_exit_body_entered")
		and player != null
	):
		ui._on_exit_body_entered(player)


func _refresh_exit_look() -> void:
	if final_exit and final_exit.has_method("set_active_look"):
		final_exit.set_active_look(exit_unlocked)


func _find_ui_ingame() -> Node:
	var tree := get_tree()
	if tree != null:
		var from_group := tree.get_first_node_in_group("ui_ingame")
		if from_group != null:
			return from_group
	var n: Node = self
	while n != null:
		var ui := n.get_node_or_null("ui_ingame")
		if ui != null:
			return ui
		n = n.get_parent()
	if tree != null and tree.current_scene != null:
		return tree.current_scene.get_node_or_null("ui_ingame")
	return null

func _show_exit_unlocked_notice() -> void:
	var tree := get_tree()

	if tree == null:
		return

	get_tree().call_group(
	"notice_manager",
	"show_notice_from_label",
	"ExitUnlockedNotice"
)
