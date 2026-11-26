extends Node
signal progress_changed
const SAVE_PATH := "user://theme_b_progress.cfg"
const ORDER := ["tutorial", "level1", "level2", "level3"]
var completed: Dictionary = {}
func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for key in cfg.get_section_keys("completed"):
			completed[key] = cfg.get_value("completed", key, false)
func mark_completed_for_scene(scene_path: String) -> void:
	for key in ORDER:
		if scene_path == "res://theme_b/%s/main.tscn" % key:
			completed[key] = true
			var cfg := ConfigFile.new()
			for saved in completed:
				cfg.set_value("completed", saved, completed[saved])
			cfg.save(SAVE_PATH)
			progress_changed.emit()
func is_level_unlocked(key: String) -> bool:
	var index := ORDER.find(key)
	return index <= 0 or completed.get(ORDER[index-1], false)
