extends Control

## Theme C level-select arrangement: top bar, three cards, arrows, footer.
## Callers supply the level list and colors.

static var last_scene_for := {}

var eyebrow := ""
var heading := "选择关卡"
var levels: Array = []
var palette: Dictionary = {}
var back_scene := "res://theme_select.tscn"
var memory_key := ""
var font: Font

var _index := 0
var _previous_card: Button
var _current_card: Button
var _next_card: Button
var _previous_arrow: Button
var _next_arrow: Button
var _page_label: Label
var _parts: Dictionary = {}


static func remember_scene(key: String, scene_path: String) -> void:
	if key.is_empty() or scene_path.is_empty():
		return
	last_scene_for[key] = scene_path


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_index = _saved_index()
	_build()
	refresh()


func _saved_index() -> int:
	var saved := str(last_scene_for.get(memory_key, ""))
	if saved.is_empty():
		return 0
	for i in levels.size():
		if str(levels[i].get("scene", "")) == saved:
			return i
	return 0


func refresh() -> void:
	if _current_card == null or levels.is_empty():
		return
	_index = clampi(_index, 0, levels.size() - 1)
	_fill(_current_card, _index, true)
	_fill(_previous_card, _index - 1, false)
	_fill(_next_card, _index + 1, false)
	_previous_arrow.visible = _index > 0
	_next_arrow.visible = _index < levels.size() - 1
	_page_label.text = "%d / %d" % [_index + 1, levels.size()]


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = _color("bg", Color(0.08, 0.08, 0.08))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	layout.add_child(top)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(titles)
	_label(titles, eyebrow, 19, _color("accent", Color.WHITE))
	_label(titles, heading, 46, _color("ink", Color.WHITE))
	if not back_scene.is_empty():
		var back := _button("返回主题", Vector2(142, 48), false)
		back.pressed.connect(_on_back)
		top.add_child(back)
	var quit := _button("退出游戏", Vector2(142, 48), false)
	quit.pressed.connect(_on_quit)
	top.add_child(quit)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	center.add_child(row)

	_previous_card = _make_card(row)
	_previous_card.pressed.connect(func() -> void: _step(-1))
	_previous_arrow = _arrow(row, "←", -1)
	_current_card = _make_card(row)
	_current_card.pressed.connect(_start)
	_next_arrow = _arrow(row, "→", 1)
	_next_card = _make_card(row)
	_next_card.pressed.connect(func() -> void: _step(1))

	var footer := VBoxContainer.new()
	layout.add_child(footer)
	_page_label = _label(footer, "", 20, _color("ink", Color.WHITE))
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _label(footer, "点击中间卡片进入关卡  ·  ← → 切换", 18, _color("muted", Color(0.7, 0.7, 0.7)))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _make_card(parent: HBoxContainer) -> Button:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(340, 460)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)
	var card := _button("", Vector2(340, 460), true)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(card)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 24)
	card.add_child(pad)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(content)
	var cover := Panel.new()
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = _color("cover", Color(0.16, 0.16, 0.16))
	cover_style.border_color = _color("card_border", Color(0.5, 0.5, 0.5))
	cover_style.set_border_width_all(2)
	cover_style.set_corner_radius_all(8)
	cover.add_theme_stylebox_override("panel", cover_style)
	content.add_child(cover)
	var grid := GridCover.new()
	grid.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.visible = false
	cover.add_child(grid)
	var level_name := _label(content, "", 30, _color("ink", Color.WHITE))
	var action := _label(content, "", 17, _color("muted", Color(0.7, 0.7, 0.7)))
	_parts[card] = {"name": level_name, "action": action, "grid": grid}
	return card


func _arrow(parent: HBoxContainer, glyph: String, direction: int) -> Button:
	var arrow := _button(glyph, Vector2(58, 70), false)
	arrow.add_theme_font_size_override("font_size", 34)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.pressed.connect(func() -> void: _step(direction))
	parent.add_child(arrow)
	return arrow


func _fill(card: Button, index: int, focused: bool) -> void:
	var parts: Dictionary = _parts[card]
	var slot := card.get_parent() as CanvasItem
	var available := index >= 0 and index < levels.size()
	card.disabled = not available
	if slot != null:
		slot.visible = available
	if not available:
		return
	var info: Dictionary = levels[index]
	var locked := bool(info.get("locked", false))
	(parts["name"] as Label).text = str(info.get("name", ""))
	var grid := parts["grid"] as GridCover
	grid.rows = _grid_rows(str(info.get("grid", "")))
	grid.visible = not grid.rows.is_empty()
	grid.queue_redraw()
	if locked:
		(parts["action"] as Label).text = "未解锁"
	elif focused:
		(parts["action"] as Label).text = "点击开始关卡"
	else:
		(parts["action"] as Label).text = "点击预览"
	card.modulate = Color(1, 1, 1, 0.45 if locked else (1.0 if focused else 0.6))
	card.scale = Vector2.ONE if focused else Vector2.ONE * 0.86


func _step(direction: int) -> void:
	var target := clampi(_index + direction, 0, levels.size() - 1)
	if target == _index:
		return
	_index = target
	refresh()


func _start() -> void:
	if _index < 0 or _index >= levels.size():
		return
	var info: Dictionary = levels[_index]
	if bool(info.get("locked", false)):
		return
	var path := str(info.get("scene", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Scene not found: %s" % path)
		return
	remember_scene(memory_key, path)
	get_tree().change_scene_to_file(path)


func _on_back() -> void:
	if not back_scene.is_empty():
		get_tree().change_scene_to_file(back_scene)


func _on_quit() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_LEFT:
		_step(-1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_RIGHT:
		_step(1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_start()
		get_viewport().set_input_as_handled()


func _button(text: String, minimum: Vector2, prominent: bool) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum
	var ink := _color("ink", Color.WHITE)
	var muted := _color("muted", Color(0.7, 0.7, 0.7))
	button.add_theme_font_size_override("font_size", 20)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	button.add_theme_color_override("font_disabled_color", muted)
	if font != null:
		button.add_theme_font_override("font", font)
	var accent := _color("accent", Color.WHITE)
	var fill := _color("card", Color(0.14, 0.14, 0.14))
	var border := accent if prominent else _color("card_border", Color(0.55, 0.55, 0.55))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = border
		box.set_border_width_all(3 if prominent else 2)
		box.set_corner_radius_all(10)
		if state == "hover":
			box.bg_color = fill.lightened(0.08)
		if state == "pressed":
			box.bg_color = fill.lightened(0.16)
		if state == "disabled":
			box.bg_color = fill.darkened(0.05)
		button.add_theme_stylebox_override(state, box)
	return button


func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font != null:
		label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label


func _grid_rows(text: String) -> PackedStringArray:
	var parts := text.split(",", false)
	if parts.size() != 6:
		return PackedStringArray()
	var rows := PackedStringArray()
	for part in parts:
		var row := str(part).strip_edges()
		if row.length() != 6:
			return PackedStringArray()
		rows.append(row)
	return rows


func _color(key: String, fallback: Color) -> Color:
	if palette.has(key):
		return palette[key] as Color
	return fallback


class GridCover extends Control:
	var rows: PackedStringArray = PackedStringArray()

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		if rows.size() != 6:
			return
		var cells := 6
		var joint := 4.0
		var margin := 10.0
		var art_size := minf(size.x, size.y) - margin * 2.0
		if art_size <= 1.0:
			return
		var origin := Vector2((size.x - art_size) * 0.5, (size.y - art_size) * 0.5)
		var cell := (art_size - joint * float(cells + 1)) / float(cells)
		for y in cells:
			var row := rows[y]
			for x in cells:
				var cell_origin := origin + Vector2(joint, joint) + Vector2(float(x), float(y)) * (cell + joint)
				var cell_rect := Rect2(cell_origin, Vector2(cell, cell))
				if x >= row.length() or row[x] != "#":
					continue
				var color := _cell_color(x, y)
				draw_rect(cell_rect, color)
				var lift := minf(color.r + 0.06, 1.0)
				var edge := Color(lift, lift, lift, 1.0)
				draw_line(cell_rect.position, cell_rect.position + Vector2(cell, 0.0), edge, 1.5)
				draw_line(cell_rect.position, cell_rect.position + Vector2(0.0, cell), edge, 1.5)

	func _cell_color(x: int, y: int) -> Color:
		var sweep := clampf((float(y) * 0.7 + float(x) * 0.3) / 5.0, 0.0, 1.0)
		var body := lerpf(0.74, 0.92, 0.35 + sweep * 0.65)
		return Color(body, body, body)
