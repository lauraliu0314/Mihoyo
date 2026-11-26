extends Control
## Horizontal level select. The focused card stays centered.

const FONT_PATH := "res://inbetween_scene/UI/Source Han Sans CN.ttf"
const CARD_SIZE := Vector2(480, 640)
const SIDE_SCALE := 0.86
const PEEK := 250.0
const DRAG_CLICK_THRESHOLD := 12.0
const GRID_PATH := "res://MainMenu/card_grids.cfg"
const LEVELS: Array[Dictionary] = [
	{
		"key": "level_tutorial",
		"title": "教学关",
		"scene": "res://level_tutorial/main.tscn",
		"pattern": 0,
	},
	{
		"key": "level_new",
		"title": "第一关",
		"scene": "res://level_new/main.tscn",
		"pattern": 0,
	},
	{
		"key": "level_new2",
		"title": "第二关",
		"scene": "res://level_new2/main.tscn",
		"pattern": 1,
	},
	{
		"key": "level_new3",
		"title": "第三关",
		"scene": "res://level_new3/main.tscn",
		"pattern": 2,
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
var _saved_grids: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = load(FONT_PATH) as Font
	_load_grids()
	_build_background()
	_build_quit_button()
	_build_cards()
	_apply_unlocks()
	var progress := get_node_or_null("/root/LevelProgress")
	if progress != null and progress.has_signal("progress_changed"):
		progress.progress_changed.connect(_apply_unlocks)
	resized.connect(_layout_cards)
	if size.x < 10.0:
		await get_tree().process_frame
	_layout_cards()


func _build_background() -> void:
	var bg := LevelBackdrop.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)


func _build_cards() -> void:
	for info in LEVELS:
		var card := FragmentCard.new()
		card.pattern = int(info["pattern"])
		card.title = str(info["title"])
		card.font = _font
		card.rows = _grid_for(str(info["key"]), int(info["pattern"]))
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
	_build_theme_button()


func _build_theme_button() -> void:
	var button := Button.new()
	button.text = "返回主题"
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	button.offset_left = 0.0
	button.offset_top = -80.0
	button.offset_right = 200.0
	button.offset_bottom = 0.0
	button.grow_horizontal = Control.GROW_DIRECTION_END
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
	button.pressed.connect(_on_theme_pressed)
	add_child(button)


func _on_theme_pressed() -> void:
	_go_to_scene("res://theme_select.tscn")


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_content_margin_all(8)
	return style


func _on_quit_pressed() -> void:
	get_tree().quit()


func _apply_unlocks() -> void:
	for i in _cards.size():
		var card := _cards[i] as FragmentCard
		card.set_unlocked(_is_unlocked(str(LEVELS[i]["key"])))


func _is_unlocked(key: String) -> bool:
	var progress := get_node_or_null("/root/LevelProgress")
	if progress == null:
		return key == str(LEVELS[0]["key"])
	return bool(progress.is_level_unlocked(key))


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
	_set_offset(clampf(raw, -0.12, float(LEVELS.size() - 1) + 0.12))


func _end_drag(local_pos: Vector2) -> void:
	if not _dragging:
		return
	_dragging = false
	if _moved < DRAG_CLICK_THRESHOLD:
		_handle_click(local_pos)
		return
	_snap_to(clampi(roundi(_offset), 0, LEVELS.size() - 1))


func _handle_click(local_pos: Vector2) -> void:
	var hit := _hit_card(local_pos)
	if hit < 0:
		_snap_to(clampi(roundi(_offset), 0, LEVELS.size() - 1))
		return
	var focused := clampi(roundi(_offset), 0, LEVELS.size() - 1)
	if hit == focused:
		_enter_level(hit)
		return
	_snap_to(hit)


func _hit_card(local_pos: Vector2) -> int:
	var best := -1
	var best_dist := INF
	for i in _cards.size():
		var card := _cards[i] as FragmentCard
		var center := card.position + CARD_SIZE * 0.5
		var half := CARD_SIZE * card.scale * 0.5
		if not Rect2(center - half, half * 2.0).has_point(local_pos):
			continue
		var dist := absf(float(i) - _offset)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


func _enter_level(index: int) -> void:
	var info: Dictionary = LEVELS[index]
	if not _is_unlocked(str(info["key"])):
		return
	var path := str(info["scene"])
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Scene not found: %s" % path)
		return
	_go_to_scene(path)


func _snap_to(index: int) -> void:
	_index = clampi(index, 0, LEVELS.size() - 1)
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
		var card := _cards[i] as FragmentCard
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


func _load_grids() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GRID_PATH) != OK or not cfg.has_section("grids"):
		return
	for key in cfg.get_section_keys("grids"):
		_saved_grids[key] = str(cfg.get_value("grids", key, ""))


func _grid_for(key: String, pattern: int) -> PackedStringArray:
	var parsed := _parse_grid(str(_saved_grids.get(key, "")))
	if not parsed.is_empty():
		return parsed
	return _default_grid(pattern)


func _parse_grid(text: String) -> PackedStringArray:
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


func _default_grid(pattern: int) -> PackedStringArray:
	var rows := PackedStringArray()
	for y in 6:
		var row := ""
		for x in 6:
			row += "." if _default_missing(pattern, x, y) else "#"
		rows.append(row)
	return rows


func _default_missing(pattern: int, x: int, y: int) -> bool:
	if pattern == 1:
		return y == 2
	if pattern == 2:
		return (
			(x == 0 and y == 1)
			or (x == 2 and y == 0)
			or (x == 3 and y == 2)
			or (x == 5 and y == 1)
			or (x == 1 and y == 3)
			or (x == 4 and y == 4)
			or (x == 2 and y == 5)
			or (x == 5 and y == 5)
		)
	return false


class LevelBackdrop extends Control:
	const DeconFx := preload("res://assets/decon/decon_fx.gd")

	var _time := 0.0
	var _motes: Array[Dictionary] = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		for i in 36:
			_motes.append({
				"x": randf(),
				"y": randf(),
				"size": randf_range(8.0, 26.0),
				"speed": randf_range(0.008, 0.028),
				"phase": randf() * TAU,
				"color": DeconFx.burst_color(i),
			})

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _draw() -> void:
		if size.x < 2.0 or size.y < 2.0:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.04, 0.04))
		for mote in _motes:
			var x := fposmod(float(mote["x"]) + _time * float(mote["speed"]), 1.0) * size.x
			var y := float(mote["y"]) * size.y + sin(_time * 0.35 + float(mote["phase"])) * 22.0
			var mote_size := float(mote["size"])
			var color: Color = mote["color"]
			color.a = 0.32
			draw_rect(Rect2(Vector2(x, y), Vector2(mote_size, mote_size)), color)


class FragmentCard extends Control:
	var pattern := 0
	var title := ""
	var unlocked := true
	var font: Font
	var rows: PackedStringArray = PackedStringArray()
	var _lock_label: Label

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		_build_labels()

	func set_unlocked(value: bool) -> void:
		unlocked = value
		if _lock_label != null:
			_lock_label.visible = not unlocked
		queue_redraw()

	func _build_labels() -> void:
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

		_lock_label = Label.new()
		_lock_label.text = "未解锁"
		_lock_label.visible = not unlocked
		_lock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_lock_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_lock_label.position = Vector2(0, size.y - 100)
		_lock_label.size = Vector2(size.x, 36)
		_lock_label.add_theme_font_size_override("font_size", 20)
		_lock_label.add_theme_color_override("font_color", Color(0.66, 0.66, 0.66))
		if font != null:
			_lock_label.add_theme_font_override("font", font)
		add_child(_lock_label)

	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		var dim := 1.0 if unlocked else 0.45
		draw_rect(rect, Color(0.07, 0.07, 0.07))
		var margin := 24.0
		var art_size := size.x - margin * 2.0
		var art := Rect2(margin, margin, art_size, art_size)
		draw_rect(art, Color(0.1, 0.1, 0.1))
		_draw_cells(art, dim)
		var border := Color(0.78, 0.78, 0.78, 0.9 if unlocked else 0.45)
		draw_rect(rect, border, false, 2.0)

	func _draw_cells(art: Rect2, dim: float) -> void:
		var cells := 6
		var joint := 5.0
		var cell := (art.size.x - joint * float(cells + 1)) / float(cells)
		for y in cells:
			for x in cells:
				var origin := art.position + Vector2(joint, joint) + Vector2(float(x), float(y)) * (cell + joint)
				var cell_rect := Rect2(origin, Vector2(cell, cell))
				if not _has_block(x, y):
					continue
				var color := _cell_color(x, y) * Color(dim, dim, dim, 1)
				draw_rect(cell_rect, color)
				var lift := minf(color.r + 0.06, 1.0)
				var edge := Color(lift, lift, lift, color.a)
				draw_line(cell_rect.position, cell_rect.position + Vector2(cell_rect.size.x, 0.0), edge, 1.5)
				draw_line(cell_rect.position, cell_rect.position + Vector2(0.0, cell_rect.size.y), edge, 1.5)
				_draw_grit(cell_rect, x, y, dim)

	func _draw_grit(cell_rect: Rect2, x: int, y: int, dim: float) -> void:
		for n in 2:
			var px := _hash01(x + n * 5, y + 2)
			var py := _hash01(x + 1, y + n * 7)
			var speck := cell_rect.position + Vector2(px, py) * cell_rect.size
			var speck_color := Color(0.08, 0.08, 0.08, 0.28 * dim) if n == 0 else Color(1, 1, 1, 0.16 * dim)
			draw_rect(Rect2(speck, Vector2(2, 2)), speck_color)

	func _cell_color(x: int, y: int) -> Color:
		var sweep := clampf((float(y) * 0.7 + float(x) * 0.3) / 5.0, 0.0, 1.0)
		var body := lerpf(0.80 * 0.92, 0.80, 0.72 + sweep * 0.2)
		body += (_hash01(x + pattern * 13, y + 3) - 0.5) * 0.06
		return Color(body, body, body)

	func _has_block(x: int, y: int) -> bool:
		if y < 0 or y >= rows.size():
			return false
		var row := rows[y]
		if x < 0 or x >= row.length():
			return false
		return row[x] == "#"

	func _hash01(x: int, y: int) -> float:
		var n := x * 374761393 + y * 668265263 + pattern * 1274126177
		n = (n ^ (n >> 13)) * 1274126177
		n = n ^ (n >> 16)
		return float(absi(n % 10000)) / 10000.0
