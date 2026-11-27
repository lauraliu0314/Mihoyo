extends RefCounted

## Shared corner placement and pause-menu stack used by themes A, B, and D.
## Theme C already builds this arrangement itself.

static func place_corner_button(button: Button, slot: String) -> void:
	if button == null:
		return
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.offset_top = 20.0
	button.offset_bottom = 82.0
	match slot:
		"menu":
			button.offset_left = -210.0
			button.offset_right = -24.0
		"help":
			button.offset_left = -430.0
			button.offset_right = -224.0
		"extra":
			button.offset_left = -650.0
			button.offset_right = -444.0


static func build_pause(parent: Node, actions: Array, palette: Dictionary = {}) -> Control:
	var overlay := Control.new()
	overlay.name = "PauseMenu"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(overlay)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.05, 0.05, 0.06, 0.72)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	var panel_style := StyleBoxFlat.new()
	var fill: Color = palette.get("card", Color(0.96, 0.97, 0.96))
	var accent: Color = palette.get("accent", Color(0.45, 0.45, 0.45))
	var ink: Color = palette.get("ink", Color(0.12, 0.14, 0.16))
	panel_style.bg_color = fill
	panel_style.border_color = accent
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var padding := MarginContainer.new()
	padding.add_theme_constant_override("margin_left", 42)
	padding.add_theme_constant_override("margin_right", 42)
	padding.add_theme_constant_override("margin_top", 32)
	padding.add_theme_constant_override("margin_bottom", 32)
	panel.add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	padding.add_child(content)
	var heading := Label.new()
	heading.text = "游戏菜单"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 38)
	heading.add_theme_color_override("font_color", ink)
	content.add_child(heading)

	for action in actions:
		var info: Dictionary = action
		var button := Button.new()
		button.text = str(info.get("text", ""))
		button.custom_minimum_size = Vector2(360, 54)
		button.focus_mode = Control.FOCUS_NONE
		button.visible = not bool(info.get("hide", false))
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", ink)
		button.add_theme_color_override("font_hover_color", ink)
		button.add_theme_color_override("font_pressed_color", ink)
		var box := StyleBoxFlat.new()
		box.bg_color = fill.lightened(0.06)
		box.border_color = accent
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		button.add_theme_stylebox_override("normal", box)
		var hover := box.duplicate() as StyleBoxFlat
		hover.bg_color = fill.lightened(0.14)
		button.add_theme_stylebox_override("hover", hover)
		var pressed := box.duplicate() as StyleBoxFlat
		pressed.bg_color = accent
		button.add_theme_stylebox_override("pressed", pressed)
		var callback: Callable = info.get("call", Callable())
		if callback.is_valid():
			button.pressed.connect(callback)
		content.add_child(button)
	return overlay
