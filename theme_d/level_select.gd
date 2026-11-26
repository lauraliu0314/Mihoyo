extends Control

const FONT_PATH := "res://Fonts/Source Han Sans CN.ttf"
const INK := Color(0.10, 0.10, 0.12)
const MUTED := Color(0.36, 0.36, 0.40)
const CREAM := Color(0.985, 0.975, 0.955)
const PINK := Color(0.96, 0.30, 0.56)
const CYAN := Color(0.18, 0.72, 0.80)
const YELLOW := Color(0.98, 0.72, 0.16)

const LEVELS := [
	{"label": "第六关 · 禅面造阶", "scene": "res://theme_d/level6/main.tscn", "tag": "06"},
]

var _font: Font

func _ready() -> void:
	if ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH)
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.62, 0.63, 0.66)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 360)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = CREAM
	panel_style.corner_radius_top_left = 30
	panel_style.corner_radius_top_right = 30
	panel_style.corner_radius_bottom_left = 30
	panel_style.corner_radius_bottom_right = 30
	panel_style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	panel_style.shadow_size = 18
	panel_style.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 42)
	margin.add_theme_constant_override("margin_right", 42)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 26)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var title := Label.new()
	title.text = "三面之外 · 主题 D"
	title.add_theme_color_override("font_color", INK)
	title.add_theme_font_size_override("font_size", 34)
	_apply_font(title)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "第六关 · 禅面造阶"
	sub.add_theme_color_override("font_color", MUTED)
	sub.add_theme_font_size_override("font_size", 17)
	_apply_font(sub)
	col.add_child(sub)

	var rule := ColorRect.new()
	rule.color = Color(0.88, 0.87, 0.84)
	rule.custom_minimum_size = Vector2(0, 2)
	col.add_child(rule)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 8)
	col.add_child(spacer)

	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	col.add_child(grid)

	for i in range(LEVELS.size()):
		var item: Dictionary = LEVELS[i]
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(430, 64)
		btn.text = "%s   %s" % [item["tag"], item["label"]]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 19)
		btn.add_theme_color_override("font_color", INK)
		btn.add_theme_color_override("font_hover_color", INK)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		_apply_font(btn)
		_style_level_button(btn, i)
		btn.pressed.connect(_open_level.bind(String(item["scene"])))
		grid.add_child(btn)

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	var back := Button.new()
	back.text = "返回主题选择"
	back.custom_minimum_size = Vector2(180, 44)
	back.add_theme_font_size_override("font_size", 17)
	back.add_theme_color_override("font_color", MUTED)
	back.add_theme_color_override("font_hover_color", INK)
	_apply_font(back)
	_style_back_button(back)
	back.pressed.connect(_back)
	bottom.add_child(back)
	col.add_child(bottom)

func _style_level_button(btn: Button, index: int) -> void:
	var accent: Color = [PINK, CYAN, YELLOW][index % 3]
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.border_color = Color(0.86, 0.85, 0.82)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(16)
	normal.content_margin_left = 18.0
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 0.99, 0.97)
	hover.border_color = accent
	hover.set_border_width_all(3)
	hover.set_corner_radius_all(16)
	hover.content_margin_left = 18.0
	hover.shadow_color = Color(accent.r, accent.g, accent.b, 0.18)
	hover.shadow_size = 8
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = accent
	pressed.border_color = accent
	pressed.set_border_width_all(3)
	pressed.set_corner_radius_all(16)
	pressed.content_margin_left = 18.0
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _style_back_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 1.0, 1.0, 0.55)
	normal.border_color = Color(0.82, 0.81, 0.78)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(12)
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(1.0, 1.0, 1.0, 0.95)
	hover.border_color = Color(0.72, 0.71, 0.68)
	hover.set_border_width_all(2)
	hover.set_corner_radius_all(12)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _apply_font(control: Control) -> void:
	if _font != null:
		control.add_theme_font_override("font", _font)

func _open_level(scene_path: String) -> void:
	get_tree().change_scene_to_file(scene_path)

func _back() -> void:
	get_tree().change_scene_to_file("res://theme_select.tscn")
