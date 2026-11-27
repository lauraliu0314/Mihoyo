extends CanvasLayer

const SUCCEED_SFX_PATH := "res://assets/audio/succeed.mp3"
## Resolved .import UID -> use path load as fallback when uid:// fails (e.g. Web).
const FONT_PATH := "res://Fonts/Source Han Sans CN.ttf"
const IngameChrome := preload("res://ui_shared/ingame_chrome.gd")
const LevelSelectChrome := preload("res://ui_shared/level_select_chrome.gd")

## ????? _ready ?????? welcome Label
@export_multiline var welcome_text: String = "?????????\n?????????"
## ?????
@export_multiline var congrats_text: String = "???????????"
## ??????????????"???"??
@export var next_scene: String = ""
## ???????true ???"????"?????"???"
@export var is_zen_mode: bool = false

var won: bool = false
var _succeed_sfx: AudioStreamPlayer
var _pause_overlay: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	won = false
	var current := get_tree().current_scene
	if current != null:
		LevelSelectChrome.remember_scene("theme_a", current.scene_file_path)

	if not is_in_group("ui_ingame"):
		add_to_group("ui_ingame")

	_apply_ui_theme()

	$reload.visible = false
	$back.visible = false
	$next.visible = false
	$next2.visible = false
	$zen_mode.visible = false
	$congratulations.visible = false
	$help.visible = false
	$help_bg.visible = false
	$welcome.visible = true
	# ??????"????"??
	$recreate.visible = is_zen_mode

	$welcome.text = welcome_text
	$congratulations.text = congrats_text

	for child in get_children():
		if child is BaseButton:
			(child as BaseButton).focus_mode = Control.FOCUS_NONE

	_setup_succeed_sfx()
	_hide_welcome_after_delay()

	var game_over := get_node_or_null("GameOverPanel") as CanvasItem
	if game_over != null:
		game_over.visible = false
	var victory := get_node_or_null("VictoryPanel") as CanvasItem
	if victory != null:
		victory.visible = false

	var player := get_parent().get_node_or_null("Player")
	if player != null and player.has_signal("died"):
		player.died.connect(_on_player_died)
	_install_shared_chrome()


## Apply the Chinese font to every Label + Button descendant,
## and style buttons like the main menu (except GameOver / Victory panels).
func _apply_ui_theme() -> void:
	var font := load(FONT_PATH) as Font
	if font == null:
		push_error("???????Fonts/Source Han Sans CN.ttf")
		return
	var controls: Array[Node] = []
	_gather_text_controls(self, controls)
	for c in controls:
		(c as Control).add_theme_font_override("font", font)
		if c is Button and not SciFiButtonStyle.is_under_excluded_panel(c):
			var btn := c as Button
			var highlight := btn.name in ["next", "next2", "zen_mode", "back"]
			# Keep existing scene font sizes when set; otherwise match menu (26).
			var size := btn.get_theme_font_size("font_size")
			if size <= 0:
				size = 26
			SciFiButtonStyle.apply(btn, size, highlight)


func _gather_text_controls(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child is Label or child is Button:
			result.append(child)
		_gather_text_controls(child, result)


func _unhandled_input(event: InputEvent) -> void:
	if _pause_overlay != null and _pause_overlay.visible:
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
			_resume_shared_pause()
			get_viewport().set_input_as_handled()
		return
	if get_tree().paused or won:
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_M):
		_open_shared_pause()
		get_viewport().set_input_as_handled()
		return
	var player := get_parent().get_node_or_null("Player")
	if player != null and player.get("is_dead") == true:
		return
	var cube := get_parent().get_node_or_null("Node3D")
	if cube == null:
		return
	if event.is_action_pressed("rotate_left") and cube.has_method("_on_left_pressed"):
		cube._on_left_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_right") and cube.has_method("_on_right_pressed"):
		cube._on_right_pressed()
		get_viewport().set_input_as_handled()


func _hide_welcome_after_delay() -> void:
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid($welcome):
		$welcome.visible = false


# Compatible with old body_entered connections. If portal_absorb exists, wait for absorb.
func _on_exit_body_entered(body: Node) -> void:
	if won or body.name != "Player":
		return
	if not get_tree().get_nodes_in_group("exit_portal").is_empty():
		return
	_show_win()


func _on_exit_absorption_finished() -> void:
	show_win_after_absorb()


# Called by portal_absorb via the ui_ingame group after suction finishes.
func show_win_after_absorb() -> void:
	_show_win()


func _show_win() -> void:
	if won:
		return
	won = true
	_play_succeed_sfx()
	# Unlock next level as soon as this stage is cleared (not only when pressing Next).
	_mark_current_level_complete()
	# Zen mode: skip VictoryPanel and return to the size-picker / generate UI.
	if is_zen_mode:
		_on_recreate_pressed()
		return
	# Legacy win chrome stays hidden; dessert VictoryPanel is the win UI.
	$congratulations.visible = false
	$back.visible = false
	$next.visible = false
	$next2.visible = false
	$zen_mode.visible = false
	var game_over := get_node_or_null("GameOverPanel") as CanvasItem
	if game_over != null:
		game_over.visible = false
	_show_victory_panel()
	game_paused()


func _show_victory_panel() -> void:
	var panel := get_node_or_null("VictoryPanel") as CanvasItem
	if panel == null:
		# Fallback if panel missing from scene.
		$congratulations.visible = true
		$back.visible = true
		if not next_scene.is_empty():
			$next.visible = true
		return
	# Dim the rest of the HUD so only the dessert panel reads clearly.
	for child in get_children():
		if child is CanvasItem and child != panel:
			(child as CanvasItem).visible = false
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	# Panel copy comes from the scene (do not override text in code).
	var next_btn := panel.find_child("NextLevelButton", true, false) as Button
	if next_btn != null:
		next_btn.process_mode = Node.PROCESS_MODE_ALWAYS
		# Zen: reuse Next as recreate; otherwise hide when no next scene.
		if is_zen_mode:
			next_btn.visible = true
		else:
			next_btn.visible = not next_scene.is_empty()
	for btn_name in ["RestartButton", "QuitButton"]:
		var btn := panel.find_child(btn_name, true, false) as Button
		if btn != null:
			btn.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = true


func _on_victory_next_pressed() -> void:
	if is_zen_mode:
		_on_recreate_pressed()
		return
	_on_next_pressed()


func _setup_succeed_sfx() -> void:
	_succeed_sfx = AudioStreamPlayer.new()
	_succeed_sfx.name = "SucceedSfx"
	_succeed_sfx.bus = "Master"
	_succeed_sfx.volume_db = -4.0
	_succeed_sfx.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_succeed_sfx)
	if ResourceLoader.exists(SUCCEED_SFX_PATH):
		_succeed_sfx.stream = load(SUCCEED_SFX_PATH) as AudioStream


func _play_succeed_sfx() -> void:
	if _succeed_sfx and _succeed_sfx.stream:
		_succeed_sfx.play()


func _on_back_pressed() -> void:
	reset_level()


func _on_reload_pressed() -> void:
	reset_level()


func _on_zen_mode_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://map_generator/zen_mode.tscn")


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu/level_select.tscn")


func _on_next2_pressed() -> void:
	# ??????"????"?"?????"??????????
	_on_recreate_pressed()


func _on_recreate_pressed() -> void:
	# ????????? ZenUI????????
	var zen := get_parent().get_node_or_null("ZenUI")
	if zen != null and zen.has_method("_on_recreate_pressed"):
		zen._on_recreate_pressed()


func _on_size_menu_pressed(id: int) -> void:
	# MenuButton item selection handled by size menu callback
	var zen := get_parent().get_node_or_null("ZenUI")
	if zen == null or not zen.has_method("_generate_with_size"):
		return
	var size := 6 + id
	zen._generate_with_size(size)


func _on_help_button_pressed() -> void:
	# Always hide legacy help panel ? only show sci-fi HowToPlayLayer.
	$help.visible = false
	$help_bg.visible = false
	if has_node("ToolsExplainLayer"):
		$ToolsExplainLayer.close()
	game_paused()
	var help_layer := $HowToPlayLayer as HowToPlayLayer
	if help_layer:
		help_layer.open()
	else:
		push_error("HowToPlayLayer missing on ui_ingame")


func _on_tools_button_pressed() -> void:
	$help.visible = false
	$help_bg.visible = false
	if has_node("HowToPlayLayer"):
		$HowToPlayLayer.close()
	game_paused()
	var tools_layer := get_node_or_null("ToolsExplainLayer")
	if tools_layer != null and tools_layer.has_method("open"):
		tools_layer.open()
	else:
		push_error("ToolsExplainLayer missing on ui_ingame")


func game_paused() -> void:
	$welcome.visible = false
	$help.visible = false
	$help_bg.visible = false

	var player := get_parent().get_node_or_null("Player")
	if player != null:
		player.set_physics_process(false)
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO

	for box in _movable_boxes():
		box.freeze = true

	get_tree().paused = true


func game_continued() -> void:
	$back.visible = false
	$next.visible = false
	$next2.visible = false
	$zen_mode.visible = false
	$congratulations.visible = false
	$help.visible = false
	$help_bg.visible = false
	var victory := get_node_or_null("VictoryPanel") as CanvasItem
	if victory != null:
		victory.visible = false
	var game_over := get_node_or_null("GameOverPanel") as CanvasItem
	if game_over != null:
		game_over.visible = false
	if has_node("HowToPlayLayer"):
		$HowToPlayLayer.close()
	if has_node("ToolsExplainLayer"):
		$ToolsExplainLayer.close()

	var player := get_parent().get_node_or_null("Player")
	if player != null:
		player.set_physics_process(true)

	for box in _movable_boxes():
		box.freeze = false

	get_tree().paused = false


func _on_back_to_game_pressed() -> void:
	game_continued()


func _movable_boxes() -> Array[RigidBody3D]:
	var result: Array[RigidBody3D] = []
	var cube := get_parent().get_node_or_null("Node3D")
	if cube == null:
		return result
	for child in cube.get_children():
		if child is RigidBody3D and (
			"MovableBox" in child.name or "DeadlyBox" in child.name
		):
			result.append(child as RigidBody3D)
	return result


func reset_level() -> void:
	# ??? reload ???????????????
	var tree := get_tree()
	if tree == null:
		return
	tree.paused = false
	won = false

	# ????????? / ?? / ???????
	if is_zen_mode:
		var cube := get_parent().get_node_or_null("Node3D")
		if cube != null and cube.has_method("reset_to_start"):
			cube.reset_to_start()
		for box in _movable_boxes():
			if box.has_method("reset_to_start"):
				box.reset_to_start()
			box.freeze = false
		var player := get_parent().get_node_or_null("Player")
		if player != null and player.has_method("reset_to_start"):
			player.reset_to_start()
			player.set_physics_process(true)
		game_continued()
		return

	tree.reload_current_scene()


func _on_next_pressed() -> void:
	get_tree().paused = false
	if not next_scene.is_empty():
		_mark_current_level_complete()
		get_tree().change_scene_to_file(next_scene)


func _mark_current_level_complete() -> void:
	var progress := get_node_or_null("/root/LevelProgress")
	if progress == null:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	progress.mark_completed_for_scene(scene.scene_file_path)


func _on_player_died() -> void:
	var game_over := get_node_or_null("GameOverPanel") as CanvasItem
	if game_over == null:
		return
	var victory := get_node_or_null("VictoryPanel") as CanvasItem
	if victory != null:
		victory.visible = false
	for child in get_children():
		if child is CanvasItem and child != game_over:
			(child as CanvasItem).visible = false
	game_over.process_mode = Node.PROCESS_MODE_ALWAYS
	for btn in game_over.find_children("*", "Button", true, false):
		(btn as Button).process_mode = Node.PROCESS_MODE_ALWAYS
	game_over.visible = true
	get_tree().paused = true


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	var level_root := get_parent()
	var scene_path: String = level_root.scene_file_path if level_root != null else ""
	if scene_path.is_empty():
		push_error("??????????? scene_file_path")
		return
	get_tree().change_scene_to_file(scene_path)


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://MainMenu/level_select.tscn")


func _install_shared_chrome() -> void:
	var menu := get_node_or_null("main_menu") as Button
	var help := get_node_or_null("help_button") as Button
	IngameChrome.place_corner_button(menu, "menu")
	if help != null:
		help.visible = false
	var tools := get_node_or_null("tools_button") as Button
	if tools != null:
		tools.visible = false
	var tools_layer := get_node_or_null("ToolsExplainLayer")
	if tools_layer != null:
		tools_layer.queue_free()
	var movement := get_node_or_null("MovementHint")
	if movement != null:
		movement.queue_free()
	if menu != null:
		menu.text = "菜单"
		if menu.pressed.is_connected(_on_main_menu_pressed):
			menu.pressed.disconnect(_on_main_menu_pressed)
		menu.pressed.connect(_open_shared_pause)
	_pause_overlay = IngameChrome.build_pause(self, [
		{"text": "继续游戏", "call": _resume_shared_pause},
		{"text": "重新开始", "call": reset_level},
		{"text": "跳过关卡", "call": _on_next_pressed, "hide": next_scene.is_empty()},
		{"text": "玩法说明", "call": _open_help_from_pause},
		{"text": "返回主菜单", "call": _on_main_menu_pressed},
	], {
		"card": Color(0.12, 0.12, 0.13),
		"ink": Color(0.95, 0.95, 0.95),
		"accent": Color(0.72, 0.72, 0.72),
	})


func _open_shared_pause() -> void:
	if _pause_overlay == null or won:
		return
	var game_over := get_node_or_null("GameOverPanel") as CanvasItem
	if game_over != null and game_over.visible:
		return
	_pause_overlay.visible = true
	game_paused()


func _open_help_from_pause() -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = false
	_on_help_button_pressed()


func _resume_shared_pause() -> void:
	if _pause_overlay != null:
		_pause_overlay.visible = false
	game_continued()
