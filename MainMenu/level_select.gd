extends Control

const FONT_PATH := "res://Fonts/Source Han Sans CN.ttf"
const GRID_PATH := "res://MainMenu/card_grids.cfg"
const ChromeScript := preload("res://ui_shared/level_select_chrome.gd")
const LEVELS: Array[Dictionary] = [
	{"key": "level_tutorial", "name": "教学关", "scene": "res://level_tutorial/main.tscn"},
	{"key": "level_new", "name": "第一关", "scene": "res://level_new/main.tscn"},
	{"key": "level_new2", "name": "第二关", "scene": "res://level_new2/main.tscn"},
	{"key": "level_new3", "name": "第三关", "scene": "res://level_new3/main.tscn"},
]

var _chrome


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	get_tree().paused = false
	_chrome = ChromeScript.new()
	_chrome.eyebrow = "解构黑白"
	_chrome.memory_key = "theme_a"
	_chrome.font = load(FONT_PATH) as Font
	_chrome.palette = {
		"bg": Color(0.07, 0.07, 0.08),
		"ink": Color(0.95, 0.95, 0.95),
		"muted": Color(0.66, 0.66, 0.66),
		"accent": Color(0.82, 0.82, 0.82),
		"card": Color(0.14, 0.14, 0.14),
		"card_border": Color(0.55, 0.55, 0.55),
		"cover": Color(0.18, 0.18, 0.18),
	}
	_chrome.levels = _level_rows()
	_chrome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_chrome)
	var progress := get_node_or_null("/root/LevelProgress")
	if progress != null and progress.has_signal("progress_changed"):
		progress.progress_changed.connect(_refresh_locks)


func _level_rows() -> Array:
	var rows: Array = []
	for info in LEVELS:
		rows.append({
			"name": str(info["name"]),
			"scene": str(info["scene"]),
			"locked": not _is_unlocked(str(info["key"])),
			"grid": _saved_grid(str(info["key"])),
		})
	return rows


func _refresh_locks() -> void:
	if _chrome == null:
		return
	_chrome.levels = _level_rows()
	_chrome.refresh()


func _saved_grid(key: String) -> String:
	var cfg := ConfigFile.new()
	if cfg.load(GRID_PATH) != OK or not cfg.has_section("grids"):
		return ""
	return str(cfg.get_value("grids", key, ""))


func _is_unlocked(key: String) -> bool:
	var progress := get_node_or_null("/root/LevelProgress")
	if progress == null:
		return key == str(LEVELS[0]["key"])
	return bool(progress.is_level_unlocked(key))
