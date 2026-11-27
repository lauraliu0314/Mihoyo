@tool
extends Control

## Add new playable levels here. The matching cover can be set in the scene Inspector.
const LEVELS := [
	{"name": "教学 · 空间初识", "scene": "res://theme_c/tutorial/main.tscn"},
	{"name": "关卡01 · 重构之门", "scene": "res://theme_c/level1/main.tscn"},
	{"name": "关卡02 · 换位接力", "scene": "res://theme_c/level2/main.tscn"},
	{"name": "关卡03 · 错层回廊", "scene": "res://theme_c/level3/main.tscn"},
]

@export var level_covers: Array[Texture2D] = []

@export_group("选关切换动画")
@export_range(0.05, 1.0, 0.01) var card_travel_duration := 0.30
@export_range(0.02, 0.5, 0.01) var preview_fade_duration := 0.10
@export_range(0.5, 0.9, 0.01) var side_card_scale := 0.65
@export_range(0.0, 40.0, 1.0) var card_arc_height := 16.0

static var last_selected_index := 0

var selected_index := 0
var previous_card: Button
var current_card: Button
var next_card: Button
var previous_arrow: Button
var next_arrow: Button
var page_label: Label
var card_parts: Dictionary = {}
var _transitioning := false

const INK := Color("253746")
const MUTED := Color("89979a")
const ACCENT := Color("36a4a0")


func _ready() -> void:
	if not Engine.is_editor_hint():
		get_tree().paused = false
	selected_index = clampi(last_selected_index, 0, LEVELS.size() - 1)
	_build_menu()
	_refresh_cards()
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("f3f5f2"))
	var grid_color := Color("dce4e2", 0.52)
	for x in range(0, int(size.x), 40):
		draw_line(Vector2(x, 0), Vector2(x, size.y), grid_color, 1.0)
	for y in range(0, int(size.y), 40):
		draw_line(Vector2(0, y), Vector2(size.x, y), grid_color, 1.0)


func _build_menu() -> void:
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
	layout.add_child(top)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title_stack)
	_add_label(title_stack, "ANY SIDE UP", 19, ACCENT)
	_add_label(title_stack, "选择关卡", 46, INK)
	var quit_button := Button.new()
	quit_button.text = "退出游戏"
	quit_button.custom_minimum_size = Vector2(142, 48)
	quit_button.add_theme_font_size_override("font_size", 20)
	_style_button(quit_button, false)
	quit_button.pressed.connect(_on_quit_pressed)
	top.add_child(quit_button)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 18)
	center.add_child(row)

	previous_card = _make_card(row, false)
	previous_card.pressed.connect(func() -> void: _select_index(selected_index - 1))
	previous_arrow = _make_arrow(row, "←", -1)
	current_card = _make_card(row, true)
	current_card.pressed.connect(_start_selected)
	next_arrow = _make_arrow(row, "→", 1)
	next_card = _make_card(row, false)
	next_card.pressed.connect(func() -> void: _select_index(selected_index + 1))

	var footer := VBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(footer)
	page_label = _add_label(footer, "", 20, INK)
	page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hint := _add_label(footer, "点击中间卡片进入关卡  ·  ← → 切换  ·  游玩中按 Esc 或 M 打开菜单", 18, MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _make_card(parent: HBoxContainer, large: bool) -> Button:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(390, 550)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(slot)

	var card := Button.new()
	# All cards share the same layout, so the preview can become the centre
	# card without a visible size or typography jump at the end of the move.
	card.custom_minimum_size = Vector2(390, 550)
	card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.pivot_offset = card.custom_minimum_size * 0.5
	card.scale = Vector2.ONE if large else Vector2.ONE * side_card_scale
	card.focus_mode = Control.FOCUS_NONE
	_style_button(card, true)
	slot.add_child(card)

	var padding := MarginContainer.new()
	padding.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset := 24
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, inset)
	padding.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(padding)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padding.add_child(content)

	var cover := Panel.new()
	cover.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cover_style := StyleBoxFlat.new()
	cover_style.bg_color = Color("f7f9f7")
	cover_style.border_color = Color("cbd8d6")
	cover_style.set_border_width_all(2)
	cover_style.set_corner_radius_all(8)
	cover.add_theme_stylebox_override("panel", cover_style)
	content.add_child(cover)

	var image := TextureRect.new()
	image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(image)
	var placeholder := Label.new()
	placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	placeholder.text = "封面图待添加"
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.add_theme_color_override("font_color", MUTED)
	placeholder.add_theme_font_size_override("font_size", 21)
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cover.add_child(placeholder)

	var number := _add_label(content, "", 18, ACCENT)
	var level_name := _add_label(content, "", 30, INK)
	var action := _add_label(content, "点击开始关卡" if large else "点击预览", 17, MUTED)
	card_parts[card] = {"image": image, "placeholder": placeholder, "number": number, "name": level_name, "action": action}
	return card


func _make_arrow(parent: HBoxContainer, glyph: String, direction: int) -> Button:
	var arrow := Button.new()
	arrow.text = glyph
	arrow.custom_minimum_size = Vector2(58, 70)
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	arrow.add_theme_font_size_override("font_size", 34)
	_style_button(arrow, false)
	arrow.pressed.connect(func() -> void: _select_index(selected_index + direction))
	parent.add_child(arrow)
	return arrow


func _add_label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _style_button(button: Button, prominent: bool) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("ffffff") if prominent else Color("f8faf8")
		box.border_color = ACCENT if prominent else Color("c3cfcd")
		box.set_border_width_all(3 if prominent else 2)
		box.set_corner_radius_all(10)
		if state == "hover":
			box.bg_color = Color("eaf7f5")
		if state == "pressed":
			box.bg_color = Color("d9efec")
		if state == "disabled":
			box.bg_color = Color("f4f5f3")
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)


func _refresh_cards() -> void:
	_update_card(current_card, selected_index)
	_update_card(previous_card, selected_index - 1)
	_update_card(next_card, selected_index + 1)
	current_card.scale = Vector2.ONE
	previous_card.scale = Vector2.ONE * side_card_scale
	next_card.scale = Vector2.ONE * side_card_scale
	previous_arrow.disabled = selected_index == 0
	next_arrow.disabled = selected_index == LEVELS.size() - 1
	page_label.text = "%d / %d" % [selected_index + 1, LEVELS.size()]


func _update_card(card: Button, index: int) -> void:
	var available := index >= 0 and index < LEVELS.size()
	card.disabled = not available
	var parts: Dictionary = card_parts[card]
	if not available:
		(parts["number"] as Label).text = ""
		(parts["name"] as Label).text = "暂无关卡"
		(parts["action"] as Label).text = ""
		(parts["image"] as TextureRect).texture = null
		(parts["placeholder"] as Label).text = ""
		card.modulate = Color(1, 1, 1, 0.28)
		return
	(parts["number"] as Label).text = "关卡 %02d" % (index + 1)
	(parts["name"] as Label).text = LEVELS[index]["name"]
	(parts["action"] as Label).text = "点击开始关卡" if card == current_card else "点击预览"
	var image := parts["image"] as TextureRect
	image.texture = level_covers[index] if index < level_covers.size() else null
	(parts["placeholder"] as Label).text = "封面图待添加"
	(parts["placeholder"] as Label).visible = image.texture == null
	card.modulate = Color.WHITE if card == current_card else Color(1, 1, 1, 0.6)


func _select_index(index: int) -> void:
	if Engine.is_editor_hint():
		return
	var target := clampi(index, 0, LEVELS.size() - 1)
	if _transitioning or target == selected_index:
		return
	_transitioning = true
	var direction := signi(target - selected_index)
	var cards := [previous_card, current_card, next_card]
	var incoming_card: Button = next_card if direction > 0 else previous_card
	var outgoing_side: Button = previous_card if direction > 0 else next_card
	var resting_positions: Dictionary = {}
	for card in cards:
		resting_positions[card] = card.position

	# The small card moves and grows in one continuous tween; the current
	# card simultaneously moves into the side slot and shrinks.
	var center_slot := current_card.get_parent() as Control
	var incoming_slot := incoming_card.get_parent() as Control
	var outgoing_slot := outgoing_side.get_parent() as Control
	var incoming_destination := center_slot.position - incoming_slot.position
	var outgoing_destination := outgoing_slot.position - center_slot.position
	var incoming_start: Vector2 = resting_positions[incoming_card]
	var current_start: Vector2 = resting_positions[current_card]
	var travel := create_tween().set_parallel(true)
	incoming_card.z_index = 5
	current_card.z_index = 4
	travel.tween_property(incoming_card, "position:x", incoming_destination.x, card_travel_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(incoming_card, "scale", Vector2.ONE, card_travel_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	travel.tween_method(_set_card_lift.bind(incoming_card, incoming_start.y), 0.0, 1.0, card_travel_duration)
	travel.tween_property(incoming_card, "modulate:a", 1.0, minf(preview_fade_duration, card_travel_duration))
	travel.tween_property(current_card, "position:x", outgoing_destination.x, card_travel_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	travel.tween_property(current_card, "scale", Vector2.ONE * side_card_scale, card_travel_duration).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	travel.tween_method(_set_card_lift.bind(current_card, current_start.y), 0.0, 1.0, card_travel_duration)
	travel.tween_property(current_card, "modulate:a", 0.6, minf(preview_fade_duration, card_travel_duration))
	await travel.finished

	selected_index = target
	last_selected_index = selected_index
	_refresh_cards()
	for card in cards:
		card.position = resting_positions[card]
		card.z_index = 0
	_transitioning = false


func _set_card_lift(progress: float, card: Button, base_y: float) -> void:
	var position_now := card.position
	position_now.y = base_y - sin(PI * progress) * card_arc_height
	card.position = position_now


func _start_selected() -> void:
	if Engine.is_editor_hint():
		return
	if _transitioning:
		return
	var path: String = LEVELS[selected_index]["scene"]
	if ResourceLoader.exists(path):
		last_selected_index = selected_index
		get_tree().change_scene_to_file(path)
	else:
		push_error("Level scene is missing: " + path)


func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_LEFT:
		_select_index(selected_index - 1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_RIGHT:
		_select_index(selected_index + 1)
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_start_selected()
		get_viewport().set_input_as_handled()


func _on_quit_pressed() -> void:
	if not Engine.is_editor_hint():
		get_tree().quit()
