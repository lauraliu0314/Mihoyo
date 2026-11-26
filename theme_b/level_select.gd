extends Control
const LEVELS := ["tutorial", "level1", "level2", "level3"]
const LABELS := ["教学关", "第一关", "第二关", "第三关"]
func _ready() -> void:
	get_tree().paused = false
	if get_node_or_null("/root/ThemeBProgress") == null:
		var progress := Node.new()
		progress.name = "ThemeBProgress"
		progress.set_script(preload("res://theme_b/progress.gd"))
		get_tree().root.add_child.call_deferred(progress)
	var background := ColorRect.new()
	background.color = Color("071510")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 22)
	panel.custom_minimum_size.x = 460
	center.add_child(panel)
	var title := Label.new()
	title.text = "深夜森林 · 主题 B"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	panel.add_child(title)
	for i in range(4):
		var button := Button.new()
		button.text = LABELS[i]
		button.custom_minimum_size.y = 64
		button.add_theme_font_size_override("font_size", 28)
		button.pressed.connect(_open_level.bind(LEVELS[i]))
		panel.add_child(button)
	var back := Button.new()
	back.text = "返回主题选择"
	back.custom_minimum_size.y = 52
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://theme_select.tscn"))
	panel.add_child(back)
func _open_level(level: String) -> void:
	get_tree().change_scene_to_file("res://theme_b/%s/main.tscn" % level)
