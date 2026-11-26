extends Control
## Shared theme hub. This is the scene main runs.
## Each theme keeps its level select on its own branch.
## Theme A: res://MainMenu/level_select.tscn
## Theme B: res://theme_b/level_select.tscn

const FONT_PATH := "res://inbetween_scene/UI/Source Han Sans CN.ttf"
const CARD_SIZE := Vector2(480, 640)
const SIDE_SCALE := 0.86
const PEEK := 250.0
const DRAG_CLICK_THRESHOLD := 12.0
const THEMES: Array[Dictionary] = [
	{
		"title": "主题 A",
		"scene": "res://MainMenu/level_select.tscn",
	},
	{
		"title": "主题 B",
		"scene": "res://theme_b/level_select.tscn",
	},
	{
		"title": "主题 C",
		"scene": "res://theme_c/level_select.tscn",
	},
	{
		"title": "主题 D",
		"scene": "res://theme_d/level_select.tscn",
	},
]

var _font: Font
var _cards: Array = []
var _offset := 0.0
var _index := 0
var _dragging := false
var _press_pos := Vector2.ZERO
var _drag_origin := 0.0
var _moved := 0.0
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT_PATH) as Font
	_build_background()
	_build_title()
	_build_quit_button()
	_build_cards()
	resized.connect(_layout_cards)
	if size.x < 10.0:
		await get_tree().process_frame
	_layout_cards()


func _build_background() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.06)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)


func _build_title() -> void:
	var title := Label.new()
	title.text = "主题选择"
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.offset_left = -320.0
	title.offset_top = 28.0
	title.offset_right = 320.0
	title.offset_bottom = 96.0
	title.grow_horizontal = Control.GROW_DIRECTION_BOTH
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	if _font != null:
		title.add_theme_font_override("font", _font)
	title.z_index = 20
	add_child(title)


func _build_cards() -> void:
	for info in THEMES:
		var card := ThemeCard.new()
		card.title = str(info["title"])
		card.font = _font
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.custom_minimum_size = CARD_SIZE
		card.size = CARD_SIZE
		add_child(card)
		_cards.append(card)


func _build_quit_button() -> void:
	var button := Button.new()
	button.text = "退出游戏"
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button.offset_left = -200.0
	button.offset_top = -80.0
	button.offset_right = 0.0
	button.offset_bottom = 0.0
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.9, 0.9, 0.9))
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_stylebox_override("normal", _button_style(Color(0.14, 0.14, 0.14), Color(0.75, 0.75, 0.75)))
	button.add_theme_stylebox_override("hover", _button_style(Color(0.22, 0.22, 0.22), Color(0.88, 0.88, 0.88)))
	button.add_theme_stylebox_override("pressed", _button_style(Color(0.32, 0.32, 0.32), Color(0.95, 0.95, 0.95)))
	button.z_index = 20
	button.pressed.connect(_on_quit_pressed)
	add_child(button)


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	return style


func _on_quit_pressed() -> void:
	get_tree().quit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		_begin_drag(get_local_mouse_position())
		accept_event()


func _input(event: InputEvent) -> void:
	if not _dragging:
		return
	var viewport := get_viewport()
	if event is InputEventMouseMotion:
		_drag_to(get_local_mouse_position())
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or mb.pressed:
			return
		var pos := get_local_mouse_position()
		if viewport != null:
			viewport.set_input_as_handled()
		_end_drag(pos)
		return
	else:
		return
	if viewport != null:
		viewport.set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if _dragging or not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	var code := key.keycode if key.keycode != 0 else key.physical_keycode
	if code != KEY_LEFT and code != KEY_RIGHT:
		return
	var direction := -1 if code == KEY_LEFT else 1
	_snap_to(_index + direction)
	var viewport := get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _begin_drag(local_pos: Vector2) -> void:
	_dragging = true
	_press_pos = local_pos
	_drag_origin = _offset
	_moved = 0.0
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _drag_to(local_pos: Vector2) -> void:
	var dx := local_pos.x - _press_pos.x
	_moved = maxf(_moved, absf(dx))
	var stride := maxf(_stride(), 1.0)
	var raw := _drag_origin - dx / stride
	_set_offset(clampf(raw, -0.12, float(THEMES.size() - 1) + 0.12))


func _end_drag(local_pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	if _moved < DRAG_CLICK_THRESHOLD:
		_handle_click(local_pos)
		return
	_snap_to(clampi(roundi(_offset), 0, THEMES.size() - 1))


func _handle_click(local_pos: Vector2) -> void:
	var hit := _hit_card(local_pos)
	if hit < 0:
		_snap_to(clampi(roundi(_offset), 0, THEMES.size() - 1))
		return
	var focused := clampi(roundi(_offset), 0, THEMES.size() - 1)
	if hit == focused:
		_enter_theme(hit)
		return
	_snap_to(hit)


func _hit_card(local_pos: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for i in _cards.size():
		var card := _cards[i] as ThemeCard
		var center := card.position + CARD_SIZE * 0.5
		var half := CARD_SIZE * card.scale * 0.5
		if not Rect2(center - half, half * 2.0).has_point(local_pos):
			continue
		var dist := absf(float(i) - _offset)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


func _enter_theme(index: int) -> void:
	var info: Dictionary = THEMES[index]
	var path := str(info["scene"])
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Scene not found: %s" % path)
		return
	_go_to_scene(path)


func _snap_to(index: int) -> void:
	_index = clampi(index, 0, THEMES.size() - 1)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_offset, _offset, float(_index), 0.28)


func _set_offset(value: float) -> void:
	_offset = value
	_layout_cards()


func _layout_cards() -> void:
	if _cards.is_empty() or size.x < 2.0:
		return
	var stride := _stride()
	var origin_y := clampf((size.y - CARD_SIZE.y) * 0.5, 24.0, maxf(24.0, size.y - CARD_SIZE.y - 24.0))
	var origin_x := (size.x - CARD_SIZE.x) * 0.5
	for i in _cards.size():
		var card := _cards[i] as ThemeCard
		var dist := absf(float(i) - _offset)
		var blend := clampf(dist, 0.0, 1.0)
		card.position = Vector2(origin_x + (float(i) - _offset) * stride, origin_y)
		card.pivot_offset = CARD_SIZE * 0.5
		card.scale = Vector2.ONE * lerpf(1.0, SIDE_SCALE, blend)
		card.modulate = Color(1, 1, 1, lerpf(1.0, 0.42, blend))
		card.z_index = int((1.0 - clampf(dist, 0.0, 2.0)) * 10.0)


func _stride() -> float:
	var side_half := CARD_SIZE.x * SIDE_SCALE * 0.5
	return maxf(size.x * 0.5 - PEEK + side_half, CARD_SIZE.x * 0.72)


func _go_to_scene(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.call_deferred("change_scene_to_file", path)


class ThemeCard extends Control:
	var title := ""
	var font: Font

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_build_label()

	func _build_label() -> void:
		var title_label := Label.new()
		title_label.text = title
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		title_label.position = Vector2(0, size.y - 156)
		title_label.size = Vector2(size.x, 48)
		title_label.add_theme_font_size_override("font_size", 32)
		title_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		if font != null:
			title_label.add_theme_font_override("font", font)
		add_child(title_label)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.07, 0.07, 0.07))
		var margin := 24.0
		var art_size := size.x - margin * 2.0
		var art := Rect2(margin, margin, art_size, art_size)
		draw_rect(art, Color(0.1, 0.1, 0.1))
		draw_rect(rect, Color(0.78, 0.78, 0.78, 0.9), false, 2.0)
