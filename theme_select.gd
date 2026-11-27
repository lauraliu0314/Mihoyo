extends Control
## Shared theme hub. This is the scene main runs.
## Each theme keeps its level select on its own branch.
## Theme A: res://MainMenu/level_select.tscn
## Theme B: res://theme_b/level_select.tscn

const FONT_PATH := "res://inbetween_scene/UI/Source Han Sans CN.ttf"
const CARD_SIZE := Vector2(640, 480)
const CARD_DROP := 64.0
const SIDE_SCALE := 0.86
const PEEK := 250.0
const DRAG_CLICK_THRESHOLD := 12.0
const THEMES: Array[Dictionary] = [
	{
		"kicker": "主题 A",
		"title": "解构黑白",
		"corner": "br",
		"scene": "res://MainMenu/level_select.tscn",
	},
	{
		"kicker": "主题 B",
		"title": "深夜森林",
		"corner": "tl",
		"scene": "res://theme_b/level_select.tscn",
	},
	{
		"kicker": "主题 C",
		"title": "原色魔方",
		"corner": "br",
		"scene": "res://theme_c/level_select.tscn",
	},
	{
		"kicker": "彩蛋关卡",
		"title": "多彩软糖",
		"corner": "tl",
		"scene": "res://theme_d/level_select.tscn",
	},
]

static var last_index := 0

var _font: Font
var _cards: Array = []
var _offset := 0.0
var _index := 0
var _dragging := false
var _press_pos := Vector2.ZERO
var _drag_origin := 0.0
var _moved := 0.0
var _tween: Tween
var _dots: PageDots


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_index = clampi(last_index, 0, THEMES.size() - 1)
	_offset = float(_index)
	_font = load(FONT_PATH) as Font
	_build_background()
	_build_title()
	_build_dots()
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
	var texture := load("res://assets/bg/theme_select_bg.png") as Texture2D
	if texture == null:
		return
	var art := TextureRect.new()
	art.texture = texture
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.modulate = Color(1, 1, 1, 0.28)
	add_child(art)


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
	var rule := ColorRect.new()
	rule.color = Color(0.95, 0.95, 0.95)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rule.offset_left = -36.0
	rule.offset_top = 102.0
	rule.offset_right = 36.0
	rule.offset_bottom = 104.0
	rule.grow_horizontal = Control.GROW_DIRECTION_BOTH
	rule.z_index = 20
	add_child(rule)


func _build_dots() -> void:
	_dots = PageDots.new()
	_dots.count = THEMES.size()
	_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dots.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_dots.offset_left = -90.0
	_dots.offset_top = -52.0
	_dots.offset_right = 90.0
	_dots.offset_bottom = -20.0
	_dots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dots.z_index = 20
	add_child(_dots)


func _build_cards() -> void:
	for info in THEMES:
		var card := ThemeCard.new()
		card.kicker = str(info["kicker"])
		card.title = str(info["title"])
		card.align_bottom_right = str(info["corner"]) == "br"
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
	button.offset_left = -224.0
	button.offset_top = -104.0
	button.offset_right = -24.0
	button.offset_bottom = -24.0
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if _font != null:
		button.add_theme_font_override("font", _font)
	button.add_theme_font_size_override("font_size", 30)
	button.add_theme_color_override("font_color", Color(0.94, 0.94, 0.94))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(0.16, 0.16, 0.16))
	button.add_theme_stylebox_override("normal", _mono_button_style(Color(0.10, 0.10, 0.10, 0.92), Color(0.72, 0.72, 0.72)))
	button.add_theme_stylebox_override("hover", _mono_button_style(Color(0.20, 0.20, 0.20), Color(0.92, 0.92, 0.92)))
	button.add_theme_stylebox_override("pressed", _mono_button_style(Color(0.88, 0.88, 0.88), Color(1, 1, 1), 3))
	button.z_index = 20
	button.pressed.connect(_on_quit_pressed)
	add_child(button)


func _mono_button_style(bg: Color, border: Color, border_w: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_w)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
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
	last_index = index
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
	var origin_y := clampf((size.y - CARD_SIZE.y) * 0.5 + CARD_DROP, 24.0, maxf(24.0, size.y - CARD_SIZE.y - 24.0))
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
		var next_focus := 1.0 - blend
		if not is_equal_approx(card.focus, next_focus):
			card.focus = next_focus
			card.queue_redraw()
	if _dots != null:
		var active := clampi(roundi(_offset), 0, THEMES.size() - 1)
		if _dots.active != active:
			_dots.active = active
			_dots.queue_redraw()


func _stride() -> float:
	var side_half := CARD_SIZE.x * SIDE_SCALE * 0.5
	return maxf(size.x * 0.5 - PEEK + side_half, CARD_SIZE.x * 0.72)


func _go_to_scene(path: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	tree.call_deferred("change_scene_to_file", path)


class ThemeCard extends Control:
	var kicker := ""
	var title := ""
	var font: Font
	var align_bottom_right := false
	var focus := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_build_labels()

	func _build_labels() -> void:
		var kicker_label := _make_label(kicker, 20)
		var title_label := _make_label(title, 36)
		var pad := 28.0
		var inner_w := size.x - pad * 2.0
		if align_bottom_right:
			kicker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			title_label.position = Vector2(pad, size.y - pad - 44.0)
			title_label.size = Vector2(inner_w, 44.0)
			kicker_label.position = Vector2(pad, title_label.position.y - 30.0)
			kicker_label.size = Vector2(inner_w, 28.0)
		else:
			kicker_label.position = Vector2(pad, 22.0)
			kicker_label.size = Vector2(inner_w, 28.0)
			title_label.position = Vector2(pad, 52.0)
			title_label.size = Vector2(inner_w, 48.0)
		add_child(kicker_label)
		add_child(title_label)

	func _make_label(label_text: String, font_size: int) -> Label:
		var label := Label.new()
		label.text = label_text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", font_size)
		label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
		if font != null:
			label.add_theme_font_override("font", font)
		return label

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		draw_rect(rect, Color(0.08, 0.08, 0.08))
		var border := Color(0.45, 0.45, 0.45).lerp(Color(0.95, 0.95, 0.95), focus)
		draw_rect(rect, border, false, lerpf(1.5, 2.5, focus))


class PageDots extends Control:
	var count := 4
	var active := 0

	func _draw() -> void:
		if count <= 0 or size.x < 2.0:
			return
		var gap := 22.0
		var radius := 5.5
		var total := gap * float(count - 1)
		var origin := Vector2((size.x - total) * 0.5, size.y * 0.5)
		var ink := Color(0.95, 0.95, 0.95)
		for i in count:
			var point := origin + Vector2(gap * float(i), 0.0)
			if i == active:
				draw_circle(point, radius, ink)
			else:
				draw_arc(point, radius, 0.0, TAU, 24, ink, 1.5, true)
