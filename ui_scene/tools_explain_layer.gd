extends Control
class_name ToolsExplainLayer

## 道具说明弹层：显示 tools_explain.png，暂停中仍可点「返回游戏」。
signal return_requested

const FONT_PATH := "res://Fonts/Source Han Sans CN.ttf"
const IMAGE_PATH := "res://tools_explain.png"
## 新图是 3:2 横版。在 1920×1080 里给标题和按钮留出空间后的最大显示尺寸。
const IMAGE_MAX_SIZE := Vector2(1050, 700)
const CYAN := Color("#3ee4ee")
const CYAN_DIM := Color("#276f84")
const PANEL_BG := Color("#0b1928f8")

var _panel: PanelContainer
var _tween: Tween
var _font: Font


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 200
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font = load(FONT_PATH) as Font
	_build_interface()
	visible = false


func open() -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	move_to_front()
	if _tween != null:
		_tween.kill()
	_panel.pivot_offset = _panel.size * 0.5
	_panel.scale = Vector2(0.96, 0.96)
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "modulate:a", 1.0, 0.20).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_property(self, "modulate:a", 0.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await _tween.finished
	visible = false
	modulate = Color.WHITE


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		return_requested.emit()
		get_viewport().set_input_as_handled()


func _build_interface() -> void:
	var shade := ColorRect.new()
	shade.color = Color("#06111ddd")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24.0
	center.offset_top = 16.0
	center.offset_right = -24.0
	center.offset_bottom = -16.0
	add_child(center)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", _style(PANEL_BG, 18, CYAN_DIM, 2))
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	margin.add_child(content)

	var title := _label("道具说明", 40, Color("#f4f8ff"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var subtitle := _label("◆  TOOLS  ◆", 16, CYAN)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)

	var image_host := CenterContainer.new()
	image_host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(image_host)

	var texture_rect := TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var tex := _load_explain_texture()
	var image_size := _fit_image_size(tex)
	texture_rect.custom_minimum_size = image_size
	image_host.custom_minimum_size = image_size
	if tex != null:
		texture_rect.texture = tex
	else:
		push_warning("ToolsExplainLayer: missing %s" % IMAGE_PATH)
	image_host.add_child(texture_rect)

	var return_button := Button.new()
	return_button.text = "返回游戏"
	return_button.custom_minimum_size = Vector2(240, 48)
	return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return_button.focus_mode = Control.FOCUS_NONE
	SciFiButtonStyle.apply(return_button, 22, true)
	return_button.pressed.connect(func() -> void: return_requested.emit())
	content.add_child(return_button)

	var hint := _label("ESC 返回游戏", 14, Color("#7896b2"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

	if _font != null:
		_apply_font(self, _font)


func _fit_image_size(tex: Texture2D) -> Vector2:
	if tex == null:
		return IMAGE_MAX_SIZE
	var src := tex.get_size()
	if src.x <= 0.0 or src.y <= 0.0:
		return IMAGE_MAX_SIZE
	var scale := minf(IMAGE_MAX_SIZE.x / src.x, IMAGE_MAX_SIZE.y / src.y)
	return src * scale


func _load_explain_texture() -> Texture2D:
	if ResourceLoader.exists(IMAGE_PATH):
		var loaded := load(IMAGE_PATH)
		if loaded is Texture2D:
			return loaded as Texture2D
	# 尚未被编辑器导入时，直接从文件读 PNG。
	var abs_path := ProjectSettings.globalize_path(IMAGE_PATH)
	var img := Image.load_from_file(abs_path)
	if img == null or img.is_empty():
		return null
	return ImageTexture.create_from_image(img)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _style(color: Color, radius: int, border: Color, width: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	return result


func _apply_font(node: Node, font: Font) -> void:
	if node is Label or node is Button:
		(node as Control).add_theme_font_override("font", font)
	for child in node.get_children():
		_apply_font(child, font)
