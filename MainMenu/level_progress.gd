extends Node
## Global autoload: persists level completion state to user://progress.cfg

signal progress_changed

const SAVE_PATH := "user://progress.cfg"

## Menu / story order. Each entry unlocks after the previous is completed.
## "teach" is always playable.
const LEVEL_ORDER: Array[String] = [
	"teach",
	"level1",
	"level2",
	"level3",
	"level4",
	"level5",
	"level6",
]

const SCENE_TO_KEY := {
	"res://teach/main.tscn": "teach",
	"res://level1/main.tscn": "level1",
	"res://level1/split_view.tscn": "level1",
	"res://level2/main.tscn": "level2",
	"res://level2/split_view.tscn": "level2",
	"res://level3/main.tscn": "level3",
	"res://level4/main.tscn": "level4",
	"res://level5/main.tscn": "level5",
	"res://level6/main.tscn": "level6",
}

var completed: Dictionary = {}


func _ready() -> void:
	_load()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode != KEY_P:
		return
	unlock_all_levels()
	get_viewport().set_input_as_handled()


## Debug cheat: mark every story level complete so the whole menu unlocks.
func unlock_all_levels() -> void:
	for key in LEVEL_ORDER:
		completed[key] = true
	_save()
	progress_changed.emit()
	print("LevelProgress: all levels unlocked (P)")


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for key in cfg.get_section_keys("completed"):
			completed[key] = cfg.get_value("completed", key, false)


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in completed:
		cfg.set_value("completed", key, completed[key])
	cfg.save(SAVE_PATH)


func mark_completed(level: String) -> void:
	if level.is_empty():
		return
	completed[level] = true
	_save()


func is_completed(level: String) -> bool:
	return completed.get(level, false)


## Mark the currently loaded level complete from its scene file path.
func mark_completed_for_scene(scene_path: String) -> void:
	var key: String = SCENE_TO_KEY.get(scene_path, "")
	if key.is_empty():
		return
	mark_completed(key)


## teach always unlocked.
## level4 and level5 both unlock after level3; otherwise each unlocks after the previous.
func is_level_unlocked(level_key: String) -> bool:
	if level_key == "teach":
		return true
	# 第三关通关后，第四、五关同时解锁。
	if level_key == "level4" or level_key == "level5":
		return is_completed("level3")
	var idx := LEVEL_ORDER.find(level_key)
	if idx <= 0:
		return false
	return is_completed(LEVEL_ORDER[idx - 1])
