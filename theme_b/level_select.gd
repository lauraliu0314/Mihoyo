extends Control

const ChromeScript := preload("res://ui_shared/level_select_chrome.gd")
const LEVELS := [
	{"name": "教学关", "scene": "res://theme_b/tutorial/main.tscn"},
	{"name": "第一关", "scene": "res://theme_b/level1/main.tscn"},
	{"name": "第二关", "scene": "res://theme_b/level2/main.tscn"},
	{"name": "第三关", "scene": "res://theme_b/level3/main.tscn"},
]


func _ready() -> void:
	get_tree().paused = false
	if get_node_or_null("/root/ThemeBProgress") == null:
		var progress := Node.new()
		progress.name = "ThemeBProgress"
		progress.set_script(preload("res://theme_b/progress.gd"))
		get_tree().root.add_child.call_deferred(progress)
	var chrome = ChromeScript.new()
	chrome.eyebrow = "深夜森林"
	chrome.memory_key = "theme_b"
	chrome.palette = {
		"bg": Color("071510"),
		"ink": Color("e7f6ee"),
		"muted": Color("8b978f"),
		"accent": Color("5a7d6e"),
		"card": Color("10281c"),
		"card_border": Color("2c4a3c"),
		"cover": Color("142820"),
	}
	chrome.levels = LEVELS.duplicate(true)
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(chrome)
