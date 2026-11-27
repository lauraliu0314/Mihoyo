extends Control

const FONT_PATH := "res://Fonts/Source Han Sans CN.ttf"
const ChromeScript := preload("res://ui_shared/level_select_chrome.gd")
const LEVELS := [
	{"name": "教学 · 空间初识", "scene": "res://theme_c/tutorial/main.tscn"},
	{"name": "关卡01 · 重构之门", "scene": "res://theme_c/level1/main.tscn"},
	{"name": "关卡02 · 换位接力", "scene": "res://theme_c/level2/main.tscn"},
	{"name": "关卡03 · 错层回廊", "scene": "res://theme_c/level3/main.tscn"},
]


func _ready() -> void:
	get_tree().paused = false
	var chrome = ChromeScript.new()
	chrome.eyebrow = "原色魔方"
	chrome.memory_key = "theme_c"
	if ResourceLoader.exists(FONT_PATH):
		chrome.font = load(FONT_PATH)
	chrome.palette = {
		"bg": Color("f7f3e8"),
		"ink": Color("253746"),
		"muted": Color("8a7344"),
		"accent": Color("c6920a"),
		"card": Color("fff8e4"),
		"card_border": Color("e2c56a"),
		"cover": Color("fffaf0"),
	}
	chrome.levels = LEVELS.duplicate(true)
	chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(chrome)
