extends Node
## Global autoload: persists level completion state to user://progress.cfg

signal progress_changed

const SAVE_PATH := "user://progress.cfg"

## Menu order. The first level is always playable; the next unlocks after it.
const LEVEL_ORDER: Array[String] = [
	"level_new",
	"level_new2",
	"level_new3",
]

const SCENE_TO_KEY := {
	"res://level_new/main.tscn": "level_new",
	"res://level_new2/main.tscn": "level_new2",
	"res://level_new3/main.tscn": "level_new3",
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


## The first level is always unlocked. Each later level unlocks after the previous one.
func is_level_unlocked(level_key: String) -> bool:
	if level_key == "level_new":
		return true
	var idx := LEVEL_ORDER.find(level_key)
	if idx <= 0:
		return false
	return is_completed(LEVEL_ORDER[idx - 1])
