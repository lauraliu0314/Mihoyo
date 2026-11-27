extends CanvasLayer

const IngameChrome := preload("res://ui_shared/ingame_chrome.gd")
const LevelSelectChrome := preload("res://ui_shared/level_select_chrome.gd")


# ==================================================
# 每个关卡单独设置的参数
# ==================================================

# 下一关场景路径。
# 本独立工程：res://theme_c/level1/main.tscn
# 最后一关可以留空。
@export_file("*.tscn")
var next_scene_path: String = ""


# 留空时，保留 ui_ingame_shared.tscn 中原来的文字。
@export_multiline
var welcome_text: String = ""

@export_multiline
var victory_text: String = ""


@export_group("界面显示")

@export var show_welcome: bool = true

# 欢迎文字从透明到完全显示的时间。
@export_range(0.05, 5.0, 0.05)
var welcome_fade_in_duration: float = 0.22

# 欢迎文字完全显示后的停留时间。
@export_range(0.0, 15.0, 0.1)
var welcome_hold_duration: float = 0.8

# 欢迎文字从完全显示到透明的时间。
@export_range(0.05, 5.0, 0.05)
var welcome_fade_out_duration: float = 0.22

@export_group("胜利音效")

@export_file
var succeed_sfx_path: String = (
	"res://assets/audio/succeed.mp3"
)

@export_range(-80.0, 24.0, 0.1)
var succeed_sfx_volume_db: float = -4.0


@export_group("失败音效")

@export_file
var fail_sfx_path: String = (
	"res://assets/audio/失败1.MP3"
)

@export_range(-80.0, 24.0, 0.1)
var fail_sfx_volume_db: float = -4.0


# ==================================================
# UI 节点
# ==================================================

@onready var welcome_card: Control = $WelcomeCard
@onready var welcome_label: Label = $WelcomeCard/welcome
@onready var exit_button: Button = $exit
@onready var restart_button: Button = $back
@onready var next_button: Button = $next

@onready var congratulations_label: Label = (
	$congratulations
)

@onready var help_button: Button = $help_button
@onready var help_background: Control = $help_bg
@onready var help_panel: Control = $help

@onready var back_to_game_button: Button = (
	$help/back_to_game
)

@onready var game_over_panel: Control = (
	$GameOverPanel
)

@onready var victory_panel: Control = (
	get_node_or_null("VictoryPanel") as Control
)

@onready var victory_next_button: Button = (
	victory_panel.find_child(
		"NextLevelButton",
		true,
		false
	) as Button
	if victory_panel != null
	else null
)

@onready var victory_restart_button: Button = (
	victory_panel.find_child(
		"RestartButton",
		true,
		false
	) as Button
	if victory_panel != null
	else null
)

@onready var victory_quit_button: Button = (
	victory_panel.find_child(
		"QuitButton",
		true,
		false
	) as Button
	if victory_panel != null
	else null
)


# ==================================================
# 运行状态
# ==================================================

var won: bool = false

var _welcome_tween: Tween
var _succeed_sfx: AudioStreamPlayer
var _fail_sfx: AudioStreamPlayer
var pause_menu_overlay: Control
var _how_to_play: HowToPlayLayer


# ==================================================
# 初始化
# ==================================================

func _ready() -> void:
	# UI 在游戏暂停时仍然可以接收按钮输入。
	process_mode = Node.PROCESS_MODE_ALWAYS
	var current := get_tree().current_scene
	if current != null:
		LevelSelectChrome.remember_scene("theme_c", current.scene_file_path)

	if victory_panel != null:
		victory_panel.process_mode = (
			Node.PROCESS_MODE_ALWAYS
		)

	# 每次进入关卡都解除可能残留的暂停。
	get_tree().paused = false

	# 传送门通过这个分组寻找胜利 UI。
	if not is_in_group("ui_ingame"):
		add_to_group("ui_ingame")

	_apply_text()
	_apply_initial_visibility()
	_apply_button_styles()
	_build_pause_menu()
	_connect_buttons()
	_connect_player_death_signal()
	_setup_succeed_sfx()
	_setup_fail_sfx()
	_install_how_to_play()

	if show_welcome:
		_play_welcome_animation()


func _apply_button_styles() -> void:
	var buttons: Array[Node] = []
	_gather_buttons(self, buttons)
	for node in buttons:
		var btn := node as Button
		var size := btn.get_theme_font_size("font_size")
		if size <= 0:
			size = 26
		_apply_yellow_button(btn, size)


func _apply_yellow_button(button: Button, font_size: int) -> void:
	var fill := Color(1, 0.757, 0.19)
	var ink := Color(0.16, 0.11, 0.03)
	var border := Color(0.72, 0.48, 0.02)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", ink)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = fill
		box.border_color = border
		box.set_border_width_all(2)
		box.set_corner_radius_all(10)
		if state == "hover":
			box.bg_color = Color(1, 0.84, 0.42)
		if state == "pressed":
			box.bg_color = Color(0.9, 0.62, 0.05)
		if state == "disabled":
			box.bg_color = Color(0.86, 0.8, 0.66)
		button.add_theme_stylebox_override(state, box)


func _install_how_to_play() -> void:
	var layer := preload("res://ui_scene/how_to_play_layer.tscn").instantiate() as HowToPlayLayer
	layer.palette = {
		"shade": Color(0.16, 0.12, 0.04, 0.62),
		"panel": Color(1, 0.98, 0.93, 0.98),
		"panel_border": Color(0.85, 0.62, 0.05),
		"title": Color(0.22, 0.15, 0.04),
		"accent": Color(0.62, 0.42, 0.02),
		"goal": Color(0.4, 0.3, 0.12),
		"page": Color(0.4, 0.3, 0.12),
		"card": Color(1, 0.96, 0.86, 0.98),
		"card_border": Color(0.9, 0.68, 0.12),
		"heading": Color(0.18, 0.12, 0.03),
		"body": Color(0.28, 0.2, 0.08),
		"hint": Color(0.45, 0.35, 0.16),
		"chip": Color(1, 0.757, 0.19),
		"chip_text": Color(0.16, 0.11, 0.03),
		"button": Color(1, 0.757, 0.19),
		"button_text": Color(0.16, 0.11, 0.03),
		"button_border": Color(0.72, 0.48, 0.02),
	}
	add_child(layer)
	layer.return_requested.connect(_on_back_to_game_pressed)
	_how_to_play = layer


func _gather_buttons(node: Node, result: Array[Node]) -> void:
	for child in node.get_children():
		if child is Button:
			result.append(child)
		_gather_buttons(child, result)


func _apply_text() -> void:
	if not welcome_text.is_empty():
		welcome_label.text = welcome_text

	if not victory_text.is_empty():
		congratulations_label.text = victory_text


func _apply_initial_visibility() -> void:
	won = false

	# 欢迎文字由渐显动画负责显示。
	welcome_card.visible = false
	_set_welcome_alpha(1.0)

	restart_button.visible = false
	next_button.visible = false
	congratulations_label.visible = false

	help_button.visible = false
	back_to_game_button.text = "返回菜单"
	help_background.visible = false
	help_panel.visible = false
	exit_button.visible = true

	game_over_panel.visible = false

	if victory_panel != null:
		victory_panel.visible = false


func _build_pause_menu() -> void:
	var can_skip := not next_scene_path.is_empty() and ResourceLoader.exists(next_scene_path)
	pause_menu_overlay = IngameChrome.build_pause(self, [
		{"text": "继续游戏", "call": _resume_game},
		{"text": "重新开始", "call": restart_current_level},
		{"text": "跳过关卡", "call": _on_next_pressed, "hide": not can_skip},
		{"text": "玩法说明", "call": _on_help_button_pressed},
		{"text": "返回主菜单", "call": _on_return_to_menu_pressed},
	], {
		"card": Color("fff8e8"),
		"ink": Color(0.16, 0.11, 0.03),
		"accent": Color(1, 0.757, 0.19),
	})


func _open_pause_menu() -> void:
	if won or game_over_panel.visible:
		return
	_hide_welcome_immediately()
	pause_menu_overlay.visible = true
	exit_button.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_paused()


func _resume_game() -> void:
	pause_menu_overlay.visible = false
	exit_button.visible = true
	game_continued()


# ==================================================
# 自动连接按钮
# ==================================================

func _connect_buttons() -> void:
	# 原有界面按钮。
	_connect_button(
		exit_button,
		&"_on_exit_pressed"
	)

	_connect_button(
		restart_button,
		&"_on_back_pressed"
	)

	_connect_button(
		next_button,
		&"_on_next_pressed"
	)

	_connect_button(
		help_button,
		&"_on_help_button_pressed"
	)

	_connect_button(
		back_to_game_button,
		&"_on_back_to_game_pressed"
	)

	# 新成功面板按钮。
	_connect_button(
		victory_next_button,
		&"_on_next_pressed"
	)

	_connect_button(
		victory_restart_button,
		&"_on_back_pressed"
	)

	_connect_button(
		victory_quit_button,
		&"_on_return_to_menu_pressed"
	)


func _connect_button(
	button: BaseButton,
	method_name: StringName
) -> void:
	if button == null:
		push_error(
			"没有找到按钮：%s"
			% method_name
		)
		return

	# 游戏暂停后按钮仍然可以接收点击。
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.disabled = false

	var callback: Callable = Callable(
		self,
		method_name
	)

	if not button.pressed.is_connected(callback):
		button.pressed.connect(callback)

	button.focus_mode = Control.FOCUS_NONE


# ==================================================
# 欢迎提示：渐显、停留、渐隐
# ==================================================

func _play_welcome_animation() -> void:
	if welcome_card == null:
		return

	# 防止重复播放时保留上一个 Tween。
	_stop_welcome_tween()

	welcome_card.visible = true
	_set_welcome_alpha(0.0)

	_welcome_tween = create_tween()

	var fade_in_tweener: PropertyTweener = (
		_welcome_tween.tween_property(
			welcome_card,
			"modulate:a",
			1.0,
			welcome_fade_in_duration
		)
	)

	fade_in_tweener.set_trans(
		Tween.TRANS_SINE
	)

	fade_in_tweener.set_ease(
		Tween.EASE_OUT
	)

	_welcome_tween.tween_interval(
		welcome_hold_duration
	)

	var fade_out_tweener: PropertyTweener = (
		_welcome_tween.tween_property(
			welcome_card,
			"modulate:a",
			0.0,
			welcome_fade_out_duration
		)
	)

	fade_out_tweener.set_trans(
		Tween.TRANS_SINE
	)

	fade_out_tweener.set_ease(
		Tween.EASE_IN
	)

	_welcome_tween.tween_callback(
		_finish_welcome_animation
	)


func _finish_welcome_animation() -> void:
	if welcome_card == null:
		return

	welcome_card.visible = false
	_set_welcome_alpha(1.0)
	_welcome_tween = null


func _hide_welcome_immediately() -> void:
	_stop_welcome_tween()

	if welcome_card == null:
		return

	welcome_card.visible = false
	_set_welcome_alpha(1.0)


func _stop_welcome_tween() -> void:
	if (
		_welcome_tween != null
		and _welcome_tween.is_valid()
	):
		_welcome_tween.kill()

	_welcome_tween = null


func _set_welcome_alpha(alpha: float) -> void:
	if welcome_card == null:
		return

	var current_color: Color = (
		welcome_card.modulate
	)

	current_color.a = alpha
	welcome_card.modulate = current_color


# ==================================================
# Q / E 控制大立方体旋转
# ==================================================

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_M, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
		if _how_to_play != null and _how_to_play.visible:
			_on_back_to_game_pressed()
		elif help_panel.visible:
			_on_back_to_game_pressed()
		elif pause_menu_overlay.visible:
			_resume_game()
		else:
			_open_pause_menu()
		return

	if (
		(event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_R)
		and not get_tree().paused
		and not won
	):
		get_viewport().set_input_as_handled()
		restart_current_level()


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return

	if won:
		return

	var cube_world: Node = (
		get_parent().get_node_or_null("Node3D")
	)

	if cube_world == null:
		return

	if (
		event.is_action_pressed("rotate_left")
		and cube_world.has_method(
			"_on_left_pressed"
		)
	):
		cube_world.call("_on_left_pressed")
		get_viewport().set_input_as_handled()
		return

	if (
		event.is_action_pressed("rotate_right")
		and cube_world.has_method(
			"_on_right_pressed"
		)
	):
		cube_world.call("_on_right_pressed")
		get_viewport().set_input_as_handled()


# ==================================================
# 传送门与胜利逻辑
# ==================================================

# 保留这个函数，是为了兼容旧关卡中还没有删除的
# body_entered 信号连接。
#
# 这里绝对不能直接调用 _show_win()，
# 否则玩家刚进入锅口，场景就会暂停，
# 吸入动画无法完成。
func _on_exit_body_entered(
	_body: Node
) -> void:
	return


# 兼容手动连接的 absorption_finished 信号。
func _on_exit_absorption_finished() -> void:
	show_win_after_absorb()


# 公共传送门通过 ui_ingame 分组调用这个函数。
func show_win_after_absorb() -> void:
	if won:
		return

	won = true

	_hide_welcome_immediately()

	help_button.visible = false
	help_background.visible = false
	help_panel.visible = false
	exit_button.visible = false
	pause_menu_overlay.visible = false

	congratulations_label.visible = false
	restart_button.visible = false
	next_button.visible = false
	game_over_panel.visible = false

	if victory_panel != null:
		victory_panel.visible = true
		if victory_next_button != null:
			victory_next_button.visible = not next_scene_path.is_empty()

	_play_succeed_sfx()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _show_win() -> void:
	# Prefer the dessert VictoryPanel (same as portal absorb path).
	show_win_after_absorb()


# ==================================================
# 帮助界面
# ==================================================

func _on_help_button_pressed() -> void:
	if won:
		return

	_hide_welcome_immediately()

	pause_menu_overlay.visible = false
	help_background.visible = false
	help_panel.visible = false
	if _how_to_play != null and _how_to_play.has_method("open"):
		_how_to_play.open()

	game_paused()


func _on_back_to_game_pressed() -> void:
	if _how_to_play != null:
		_how_to_play.visible = false
	help_background.visible = false
	help_panel.visible = false

	pause_menu_overlay.visible = true
	game_paused()


# ==================================================
# 暂停与继续
# ==================================================

func game_paused() -> void:
	get_tree().paused = true


func game_continued() -> void:
	get_tree().paused = false


# ==================================================
# 重新开始
# ==================================================

# 胜利界面中的“重新开始”按钮。
func _on_back_pressed() -> void:
	restart_current_level()


# 死亡界面中的重新开始按钮也可以连接到这里。
func _on_restart_button_pressed() -> void:
	restart_current_level()


func restart_current_level() -> void:
	get_tree().paused = false

	var error: Error = (
		get_tree().reload_current_scene()
	)

	if error != OK:
		push_error(
			"重新加载当前关卡失败，错误码：%s"
			% error
		)


# ==================================================
# 下一关
# ==================================================

func _on_next_pressed() -> void:
	if next_scene_path.is_empty():
		push_warning(
			"当前 UI 没有设置 Next Scene Path"
		)
		return

	if not ResourceLoader.exists(
		next_scene_path
	):
		push_error(
			"下一关场景不存在：%s"
			% next_scene_path
		)
		return

	get_tree().paused = false

	var error: Error = (
		get_tree().change_scene_to_file(
			next_scene_path
		)
	)

	if error != OK:
		push_error(
			"进入下一关失败，错误码：%s"
			% error
		)


# ==================================================
# 游戏菜单与返回选关
# ==================================================

func _on_exit_pressed() -> void:
	_open_pause_menu()


func _on_quit_button_pressed() -> void:
	_on_return_to_menu_pressed()


func _on_return_to_menu_pressed() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://theme_c/level_select.tscn")


# ==================================================
# 玩家死亡
# ==================================================

func _connect_player_death_signal() -> void:
	var player: Node = (
		get_parent().get_node_or_null("Player")
	)

	if player == null:
		push_warning(
			"ui_ingame 没有找到 Player"
		)
		return

	if not player.has_signal("died"):
		return

	var callback: Callable = Callable(
		self,
		"_on_player_died"
	)

	if not player.is_connected(
		"died",
		callback
	):
		player.connect(
			"died",
			callback
		)


func _on_player_died() -> void:
	if won:
		return

	# 死亡信号触发后立即播放失败音效。
	_play_fail_sfx()

	# 停止并隐藏欢迎动画。
	_hide_welcome_immediately()

	# 隐藏其他界面。
	help_button.visible = false
	help_background.visible = false
	help_panel.visible = false
	exit_button.visible = false
	pause_menu_overlay.visible = false

	restart_button.visible = false
	next_button.visible = false
	congratulations_label.visible = false

	if victory_panel != null:
		victory_panel.visible = false

	game_over_panel.visible = false

	# 让失败音效比失败界面提前一点出现。
	await get_tree().create_timer(0.30).timeout

	if not is_inside_tree():
		return

	game_over_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	game_paused()


# ==================================================
# 胜利音效
# ==================================================

func _setup_succeed_sfx() -> void:
	_succeed_sfx = AudioStreamPlayer.new()

	_succeed_sfx.name = "SucceedSfx"
	_succeed_sfx.bus = "Master"
	_succeed_sfx.volume_db = (
		succeed_sfx_volume_db
	)

	# 暂停场景后仍允许音效继续播放。
	_succeed_sfx.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(_succeed_sfx)

	if succeed_sfx_path.is_empty():
		return

	if not ResourceLoader.exists(
		succeed_sfx_path
	):
		push_warning(
			"没有找到胜利音效：%s"
			% succeed_sfx_path
		)
		return

	_succeed_sfx.stream = (
		load(succeed_sfx_path)
		as AudioStream
	)


func _play_succeed_sfx() -> void:
	if _succeed_sfx == null:
		return

	if _succeed_sfx.stream == null:
		return

	_succeed_sfx.play()


# ==================================================
# 失败音效
# ==================================================

func _setup_fail_sfx() -> void:
	_fail_sfx = AudioStreamPlayer.new()

	_fail_sfx.name = "FailSfx"
	_fail_sfx.bus = "Master"
	_fail_sfx.volume_db = fail_sfx_volume_db

	# 游戏暂停后，失败音效仍然继续播放。
	_fail_sfx.process_mode = (
		Node.PROCESS_MODE_ALWAYS
	)

	add_child(_fail_sfx)

	if fail_sfx_path.is_empty():
		return

	if not ResourceLoader.exists(
		fail_sfx_path
	):
		push_warning(
			"没有找到失败音效：%s"
			% fail_sfx_path
		)
		return

	var stream: AudioStream = (
		load(fail_sfx_path) as AudioStream
	)

	_fail_sfx.stream = stream


func _play_fail_sfx() -> void:
	if _fail_sfx == null:
		return

	if _fail_sfx.stream == null:
		return

	_fail_sfx.play()
