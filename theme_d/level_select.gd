extends Control

const FONT_PATH := "res://Fonts/Source Han Sans CN.ttf"
const ChromeScript := preload("res://ui_shared/level_select_chrome.gd")


func _ready() -> void:
	get_tree().paused = false
	var chrome = ChromeScript.new()
	chrome.eyebrow = "多彩软糖"
	chrome.memory_key = "theme_d"
	if ResourceLoader.exists(FONT_PATH):
		chrome.font = load(FONT_PATH)
	chrome.palette = {
		"bg": Color(0.62, 0.63, 0.66),
		"ink": Color(0.10, 0.10, 0.12),
		"muted": Color(0.36, 0.36, 0.40),
		"accent": Color(0.96, 0.30, 0.56),
		"card": Color(0.985, 0.975, 0.955),
		"card_border": Color(0.82, 0.80, 0.76),
		"cover": Color(1, 1, 1),
	}
	chrome.levels = [
		{"name": "彩蛋：多彩软糖", "scene": "res://theme_d/level6/main.tscn"},
	]
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(chrome)
