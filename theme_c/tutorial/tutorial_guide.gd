extends CanvasLayer

@onready var cube: Node3D = get_node("../Node3D")
@onready var player: Node3D = get_node("../Player")
@onready var turn_controller: Node3D = get_node("../RubikLayerController")
@onready var step_label: Label = $GuidePanel/Margin/VBox/StepLabel
@onready var instruction_label: Label = $GuidePanel/Margin/VBox/InstructionLabel
@onready var detail_label: Label = $GuidePanel/Margin/VBox/DetailLabel
@onready var guide_panel: PanelContainer = $GuidePanel
@onready var focus_overlay: Control = $FocusOverlay
@onready var camera: Camera3D = get_node("../Marker3D/Camera3D")

@export_group("五步提示文字")
@export var step_titles: PackedStringArray = [
	"教学 1 / 5 · 移动", "教学 2 / 5 · 翻面", "教学 3 / 5 · 旋转",
	"教学 4 / 5 · 避障", "教学 5 / 5 · 到达终点",
]
@export var step_instructions: PackedStringArray = [
	"用 WASD 或方向键移动 Bready。",
	"继续朝有一排白色方块的墙移动，碰到边界就会翻面。",
	"按住出现的双箭头，沿箭头方向拖动。",
	"前方有白色方块挡路，从旁边绕过去。",
	"走进发光的黑色出口，完成这一关。",
]
@export var step_details: PackedStringArray = [
	"沿地面朝画面右侧的白色方块走。",
	"Q / E 可以调整观察视角；翻错面也能继续走回来。",
	"站在箭头所在层外，转开围住出口的白色方块。",
	"不要硬撞方块；从侧边通过，再走向出口。",
	"缺口已经出现，沿着通路进入出口。",
]
@export var wrong_face_hint := "已经翻到另一面。继续走向有黑色终点的那面墙。"

@export_group("提示卡动效")
@export_range(0.05, 0.5, 0.01) var appear_duration := 0.22
@export_range(0.05, 0.5, 0.01) var disappear_duration := 0.14
@export_range(0.8, 1.0, 0.01) var appear_scale := 0.94

var stage := 0
var visual_stage := 0
var start_position := Vector3.ZERO
var marker_root: Node3D
var turn_marker: Node3D
var exit_tile: Node3D
var _guide_tween: Tween
var _stage_initialized := false
var _suspended := false
var _wrong_face_detail := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	start_position = player.global_position
	marker_root = cube.get_node("turn_markers") as Node3D
	turn_marker = marker_root.get_node("TurnMarkerA") as Node3D
	var exit_root := cube.find_child("StaticBox_EXIT", true, false) as Node3D
	exit_tile = exit_root.get_node("ExitTile") as Node3D
	marker_root.visible = false
	turn_controller.set_process_unhandled_input(false)
	cube.flip_finished.connect(_on_flip_finished)
	turn_controller.layer_turn_finished.connect(_on_layer_turn_finished)
	_set_stage(0)


func _process(_delta: float) -> void:
	_set_suspended(get_tree().paused)
	if _suspended:
		return
	if stage == 0 and player.global_position.distance_to(start_position) > 0.7:
		_set_stage(1)
	elif stage == 3:
		var local: Vector3 = cube.to_local(player.global_position)
		if _right_wall_is_floor() and local.y > 3.35 and absf(local.z - 0.5) > 0.7:
			_set_stage(4)
	_update_focus()


func _on_flip_finished() -> void:
	if stage >= 3:
		return
	if _right_wall_is_floor():
		_wrong_face_detail = false
		_set_stage(2)
	else:
		_wrong_face_detail = true
		_set_stage(1)


func _on_layer_turn_finished(_axis: Vector3, _slice: float, _direction: int) -> void:
	if stage == 2:
		_set_stage(3)


func _right_wall_is_floor() -> bool:
	return (cube.global_basis * Vector3.LEFT).normalized().dot(Vector3.UP) > 0.92


func _set_stage(value: int) -> void:
	if _stage_initialized and stage == value:
		_apply_stage_text()
		return
	stage = value
	marker_root.visible = stage >= 2
	turn_controller.set_process_unhandled_input(stage >= 2)
	if not _stage_initialized:
		_stage_initialized = true
		visual_stage = stage
		_apply_stage_text()
		_update_focus()
		_appear()
	else:
		_disappear_for_stage()


func _apply_stage_text() -> void:
	step_label.text = step_titles[visual_stage]
	instruction_label.text = step_instructions[visual_stage]
	detail_label.text = wrong_face_hint if visual_stage == 1 and _wrong_face_detail else step_details[visual_stage]


func _stop_guide_tween() -> void:
	if _guide_tween != null and _guide_tween.is_valid():
		_guide_tween.kill()
	_guide_tween = null


func _appear() -> void:
	_stop_guide_tween()
	guide_panel.visible = true
	focus_overlay.visible = true
	guide_panel.modulate.a = 0.0
	focus_overlay.modulate.a = 0.0
	guide_panel.scale = Vector2.ONE * appear_scale
	_guide_tween = create_tween().set_parallel(true)
	_guide_tween.tween_property(guide_panel, "modulate:a", 1.0, appear_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_guide_tween.tween_property(focus_overlay, "modulate:a", 1.0, appear_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_guide_tween.tween_property(guide_panel, "scale", Vector2.ONE, appear_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _disappear_for_stage() -> void:
	_stop_guide_tween()
	_guide_tween = create_tween().set_parallel(true)
	_guide_tween.tween_property(guide_panel, "modulate:a", 0.0, disappear_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_guide_tween.tween_property(focus_overlay, "modulate:a", 0.0, disappear_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_guide_tween.chain().tween_callback(_finish_stage_change)


func _finish_stage_change() -> void:
	visual_stage = stage
	_apply_stage_text()
	_update_focus()
	if not _suspended:
		_appear()


func _set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	if value:
		_stop_guide_tween()
		_guide_tween = create_tween().set_parallel(true)
		_guide_tween.tween_property(guide_panel, "modulate:a", 0.0, disappear_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_guide_tween.tween_property(focus_overlay, "modulate:a", 0.0, disappear_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		_guide_tween.chain().tween_callback(func() -> void:
			guide_panel.visible = false
			focus_overlay.visible = false
		)
	else:
		visual_stage = stage
		_apply_stage_text()
		_update_focus()
		_appear()


func _focus_world_position() -> Vector3:
	match visual_stage:
		0:
			return player.global_position + Vector3.UP * 0.48
		1:
			return cube.to_global(Vector3(3.0, 0.7, -1.5))
		2:
			return turn_marker.global_position
		3:
			return cube.to_global(Vector3(2.5, 2.5, 0.5))
		_:
			return exit_tile.global_position


func _update_focus() -> void:
	if camera == null or camera.is_position_behind(_focus_world_position()):
		focus_overlay.visible = false
		return
	focus_overlay.visible = true
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var point: Vector2 = camera.unproject_position(_focus_world_position())
	point = point.clamp(Vector2(65, 65), viewport_size - Vector2(65, 65))
	var card_size := Vector2(520, 170)
	var card_x := point.x + 105.0 if point.x < viewport_size.x * 0.5 else point.x - card_size.x - 105.0
	var card_y := point.y - card_size.y * 0.5
	card_x = clampf(card_x, 20.0, viewport_size.x - card_size.x - 20.0)
	card_y = clampf(card_y, 20.0, viewport_size.y - card_size.y - 20.0)
	guide_panel.size = card_size
	guide_panel.position = Vector2(card_x, card_y)
	focus_overlay.set_focus(point, Rect2(guide_panel.position, card_size))
