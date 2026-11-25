extends CanvasLayer
## Sci-fi main menu layer (design: 三面之外).
## Default hidden — show with show_menu() / hide_menu().

const FONT_PATH := "res://inbetween_scene/UI/Source Han Sans CN.ttf"
# Welcome / story_style blue palette (matches SciFiButtonStyle).
const CYAN := Color(0.45, 0.68, 0.88, 1.0)
const CYAN_DIM := Color(0.288, 0.475, 0.6, 0.95)
const BTN_BG := Color(0.288, 0.475, 0.6, 0.85)
const BTN_BG_HOVER := Color(0.36, 0.56, 0.72, 0.95)
const BTN_BG_PRESSED := Color(0.22, 0.38, 0.52, 0.98)

@onready var _root: Control = $Root
@onready var _help_button: Button = $Root/TopBar/HelpButton
@onready var _start_button: Button = $Root/CenterContainer/VBoxContainer/StartButton
@onready var _level1_button: Button = $Root/CenterContainer/VBoxContainer/Level1Button
@onready var _level2_button: Button = $Root/CenterContainer/VBoxContainer/Level2Button
@onready var _level3_button: Button = $Root/CenterContainer/VBoxContainer/Level3Button
@onready var _quit_button: Button = $Root/CenterContainer/VBoxContainer/QuitButton
@onready var _how_to_play: HowToPlayLayer = $HowToPlayLayer

var _font: FontFile
var _feedback_busy := false


func _ready() -> void:
	visible = false
	layer = 20
	_font = load(FONT_PATH) as FontFile
	_apply_styles()
	_connect_buttons()
	_refresh_unlocks()
	var progress := get_node_or_null("/root/LevelProgress")
	if progress != null and progress.has_signal("progress_changed"):
		progress.progress_changed.connect(_refresh_unlocks)
	if _how_to_play:
		_how_to_play.return_requested.connect(_on_help_closed)


func show_menu() -> void:
	visible = true
	_refresh_unlocks()


func hide_menu() -> void:
	visible = false


func _connect_buttons() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_level1_button.pressed.connect(_on_level1_pressed)
	_level2_button.pressed.connect(_on_level2_pressed)
	_level3_button.pressed.connect(_on_level3_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_help_button.pressed.connect(_on_help_pressed)


func _refresh_unlocks() -> void:
	var progress := get_node_or_null("/root/LevelProgress")
	_set_level_button_state(_level1_button, true)
	if progress == null:
		_set_level_button_state(_level2_button, false)
		_set_level_button_state(_level3_button, false)
		return
	_set_level_button_state(_level2_button, progress.is_level_unlocked("level_new2"))
	_set_level_button_state(_level3_button, progress.is_level_unlocked("level_new3"))


func _set_level_button_state(btn: Button, unlocked: bool) -> void:
	if btn == null:
		return
	btn.disabled = not unlocked
	btn.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	btn.modulate = Color(1, 1, 1, 1) if unlocked else Color(0.55, 0.58, 0.62, 0.75)


func _button_feedback(btn: Button) -> void:
	if _feedback_busy or btn == null:
		return
	_feedback_busy = true
	var original_modulate := btn.modulate
	var original_scale := btn.scale
	btn.pivot_offset = btn.size * 0.5
	btn.modulate = CYAN
	btn.scale = Vector2(1.05, 1.05)
	await get_tree().create_timer(0.12).timeout
	if is_instance_valid(btn):
		btn.modulate = original_modulate
		btn.scale = original_scale
	_feedback_busy = false


func _go_to_scene(path: String) -> void:
	if path.is_empty() or not ResourceLoader.exists(path):
		push_warning("Scene not found: %s" % path)
		return
	get_tree().change_scene_to_file(path)


func _on_start_pressed() -> void:
	await _button_feedback(_start_button)
	_go_to_scene("res://level_new/main.tscn")


func _on_level1_pressed() -> void:
	await _button_feedback(_level1_button)
	_go_to_scene("res://level_new/main.tscn")


func _on_level2_pressed() -> void:
	await _button_feedback(_level2_button)
	_go_to_scene("res://level_new2/main.tscn")


func _on_level3_pressed() -> void:
	await _button_feedback(_level3_button)
	_go_to_scene("res://level_new3/main.tscn")


func _on_quit_pressed() -> void:
	await _button_feedback(_quit_button)
	get_tree().quit()


func _on_help_pressed() -> void:
	await _button_feedback(_help_button)
	if _how_to_play:
		_how_to_play.open()
	else:
		_show_help_dialog()


func _on_help_closed() -> void:
	if _how_to_play:
		_how_to_play.close()


func _show_help_dialog() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "游戏帮助"
	dialog.dialog_text = "操作说明：\n\n• WASD 移动角色\n• Q / E 水平旋转立方体\n• 移动到另一墙面会发生整体翻转\n• ZEN MODE 可进入自由探索模式\n\n祝你探索愉快！"
	dialog.ok_button_text = "知道了"
	_root.add_child(dialog)
	dialog.popup_centered(Vector2i(520, 300))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)


func _make_btn_style(bg: Color, border: Color, border_w: float = 2.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(int(border_w))
	s.set_corner_radius_all(10)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


func _style_menu_button(btn: Button, highlight: bool = false) -> void:
	var border := CYAN if highlight else CYAN_DIM
	var normal_bg := BTN_BG_PRESSED if highlight else BTN_BG
	btn.add_theme_stylebox_override("normal", _make_btn_style(normal_bg, border, 2.5 if highlight else 2.0))
	btn.add_theme_stylebox_override("hover", _make_btn_style(BTN_BG_HOVER, CYAN, 2.5))
	btn.add_theme_stylebox_override("pressed", _make_btn_style(BTN_BG_PRESSED, CYAN, 3.0))
	btn.add_theme_stylebox_override("disabled", _make_btn_style(Color(0.18, 0.24, 0.32, 0.55), Color(0.35, 0.42, 0.5, 0.5), 1.0))
	btn.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.85, 0.93, 1.0, 1.0))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.55, 0.7))
	btn.add_theme_font_size_override("font_size", 26)
	if _font:
		btn.add_theme_font_override("font", _font)
	btn.custom_minimum_size = Vector2(360, 52)


func _apply_styles() -> void:
	var title: Label = $Root/TitleCenter/TitleVBox/Title
	var subtitle: Label = $Root/TitleCenter/TitleVBox/Subtitle
	if _font:
		title.add_theme_font_override("font", _font)
		subtitle.add_theme_font_override("font", _font)
		_help_button.add_theme_font_override("font", _font)
		$Root/VersionLabel.add_theme_font_override("font", _font)

	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", CYAN_DIM)

	_style_menu_button(_start_button)
	_style_menu_button(_level1_button)
	_style_menu_button(_level2_button)
	_style_menu_button(_level3_button)
	_style_menu_button(_quit_button)

	_help_button.add_theme_font_size_override("font_size", 18)
	_help_button.add_theme_stylebox_override("normal", _make_btn_style(BTN_BG, CYAN_DIM, 1.5))
	_help_button.add_theme_stylebox_override("hover", _make_btn_style(BTN_BG_HOVER, CYAN, 2.0))
	_help_button.add_theme_stylebox_override("pressed", _make_btn_style(BTN_BG_PRESSED, CYAN, 2.0))
	_help_button.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0))
