extends CanvasLayer

## 第六关《禅面造阶》的界面层。白玻璃软糖卡片：白底、浅灰描边、圆角软阴影。
## 出口的吸收逻辑由 global_script/portal_absorb.gd 通过 ui_ingame 组触发。

const MechIcon = preload("res://theme_d/level6/mech_icon.gd")
const FONT_PATH := "res://inbetween_scene/UI/Source Han Sans CN.ttf"
const INK := Color(0.16, 0.15, 0.17)
const CREAM := Color(1.0, 1.0, 1.0)
const MAGENTA := Color(1.0, 0.0, 0.41)
const CYAN := Color(0.13, 0.83, 0.93)
const PURPLE := Color(0.49, 0.23, 0.93)
const ORANGE := Color(0.94, 0.35, 0.02)
const SOFT_BORDER := Color(0.90, 0.89, 0.87)
const SOFT_TEXT := Color(0.30, 0.28, 0.32)

var cube
var font: Font
var _toast: Label
var _toast_panel: Panel
var _toast_time := 0.0
var _flip_toast_cooldown := 0.0
var _status_timer := 0.0
var _undo_button: Button
var _win: Control
var _won := false
var _inventory_panel: Panel
var _inventory_icon: Panel
var _inventory_icon_style: StyleBoxFlat
var _inventory_count: Label
var _inventory_value := -1
var _orb_panel: Panel
var _orb_icon: Panel
var _orb_icon_style: StyleBoxFlat
var _orb_count: Label
var _orb_value := -1
var _crush_panel: Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("ui_ingame")
	get_tree().paused = false
	cube = get_parent().get_node_or_null("Node3D")
	font = load(FONT_PATH) as Font
	if font == null:
		font = ThemeDB.fallback_font
	_build_hud_chrome()
	_build_tip_card()
	_build_inventory()
	_build_orb_inventory()
	_build_crush_panel()
	_build_menu_buttons()
	_build_win_panel()
	if cube != null:
		if cube.has_signal("flip_blocked"):
			cube.flip_blocked.connect(_on_flip_blocked)
		if cube.has_signal("exit_activated"):
			cube.exit_activated.connect(_on_exit_activated)
		if cube.has_signal("orb_collected"):
			cube.orb_collected.connect(_on_orb_collected)
		if cube.has_signal("build_refused"):
			cube.build_refused.connect(_on_build_refused)
		if cube.has_signal("player_crushed"):
			cube.player_crushed.connect(_on_player_crushed)


func _process(delta: float) -> void:
	if _flip_toast_cooldown > 0.0:
		_flip_toast_cooldown -= delta
	if _toast_time > 0.0:
		_toast_time -= delta
		if _toast_time <= 0.0 and _toast != null:
			_toast.visible = false
			if _toast_panel != null:
				_toast_panel.visible = false
	_status_timer += delta
	if _status_timer >= 0.2:
		_status_timer = 0.0
		_refresh_status()
		_refresh_undo_button()
	

func _refresh_undo_button() -> void:
	if _undo_button == null or cube == null:
		return
	var state: Dictionary = cube.call("get_build_state")
	_undo_button.disabled = not bool(state.get("can_undo", false))


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _won or cube == null:
		return
	if event.is_action_pressed("rotate_left") and cube.has_method("_on_left_pressed"):
		cube._on_left_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("rotate_right") and cube.has_method("_on_right_pressed"):
		cube._on_right_pressed()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- 状态与提示

func _build_hud_chrome() -> void:
	_toast_panel = Panel.new()
	_toast_panel.name = "ToastPanel"
	_toast_panel.position = Vector2(14, 76)
	_toast_panel.size = Vector2(920, 70)
	_toast_panel.add_theme_stylebox_override(
		"panel", _soft_style(16, Color(1, 1, 1, 0.96), SOFT_BORDER, 2)
	)
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.visible = false
	add_child(_toast_panel)

	_toast = Label.new()
	_toast.name = "Toast"
	_toast.position = Vector2(30, 84)
	_toast.size = Vector2(890, 54)
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_font_size_override("font_size", 22)
	_toast.add_theme_color_override("font_color", MAGENTA)
	_toast.add_theme_color_override("font_outline_color", CREAM)
	_toast.add_theme_constant_override("outline_size", 3)
	if font != null:
		_toast.add_theme_font_override("font", font)
	_toast.visible = false
	add_child(_toast)


## 右上角紧凑流程卡：只保留四步，不放机制说明。
func _build_tip_card() -> void:
	var tip_root := Control.new()
	tip_root.name = "TipRoot"
	tip_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tip_root)
	tip_root.anchor_left = 1.0
	tip_root.anchor_right = 1.0
	tip_root.anchor_top = 0.0
	tip_root.anchor_bottom = 0.0
	tip_root.offset_left = -334.0
	tip_root.offset_right = -14.0
	tip_root.offset_top = 76.0
	tip_root.offset_bottom = 366.0

	var panel := Panel.new()
	panel.name = "TipPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel", _soft_style(20, Color(1, 1, 1, 0.94), SOFT_BORDER, 2)
	)
	tip_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	var title := Label.new()
	title.text = "通关流程"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", INK)
	if font != null:
		title.add_theme_font_override("font", font)
	box.add_child(title)

	_add_flow_row(box, MechIcon.Kind.ORB, Color(1.0, 0.72, 0.18), "1  吃金球")
	_add_flow_row(box, MechIcon.Kind.ORB, CYAN, "2  吃青球")
	_add_flow_row(box, MechIcon.Kind.FLIP, CYAN, "3  解锁出口")
	_add_flow_row(box, MechIcon.Kind.EXIT, PURPLE, "4  前往出口通关")

	var gravity_tip := Label.new()
	gravity_tip.text = "放置的物块会随重力下落，小心被砸中"
	gravity_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gravity_tip.custom_minimum_size = Vector2(0, 34)
	gravity_tip.add_theme_font_size_override("font_size", 14)
	gravity_tip.add_theme_color_override("font_color", SOFT_TEXT)
	if font != null:
		gravity_tip.add_theme_font_override("font", font)
	box.add_child(gravity_tip)


func _add_flow_row(box: VBoxContainer, kind: int, accent: Color, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.custom_minimum_size = Vector2(0, 36)
	box.add_child(row)

	var icon := MechIcon.new()
	icon.kind = kind
	icon.accent = accent
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var label := Label.new()
	label.text = text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", INK)
	if font != null:
		label.add_theme_font_override("font", font)
	row.add_child(label)


## 左侧灰区：软糖贴纸 + 卡通数量，替代原先的操作提示。
func _build_inventory() -> void:
	var root := Control.new()
	root.name = "Inventory"
	root.position = Vector2(22, 214)
	root.size = Vector2(196, 118)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_inventory_panel = Panel.new()
	_inventory_panel.name = "InventoryPanel"
	_inventory_panel.position = Vector2.ZERO
	_inventory_panel.size = Vector2(196, 118)
	_inventory_panel.add_theme_stylebox_override(
		"panel", _soft_style(22, Color(0.98, 0.97, 0.98, 0.93), SOFT_BORDER, 2)
	)
	_inventory_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_inventory_panel)

	_inventory_icon = Panel.new()
	_inventory_icon.name = "GummySticker"
	_inventory_icon.position = Vector2(14, 28)
	_inventory_icon.size = Vector2(62, 62)
	_inventory_icon.pivot_offset = _inventory_icon.size * 0.5
	_inventory_icon.rotation = deg_to_rad(-4.0)
	_inventory_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_icon_style = StyleBoxFlat.new()
	_inventory_icon_style.bg_color = MAGENTA
	_inventory_icon_style.border_color = Color(1, 1, 1, 0.95)
	_inventory_icon_style.set_border_width_all(4)
	_inventory_icon_style.set_corner_radius_all(18)
	_inventory_icon_style.shadow_color = Color(0.24, 0.20, 0.30, 0.18)
	_inventory_icon_style.shadow_size = 6
	_inventory_icon_style.shadow_offset = Vector2(0, 4)
	_inventory_icon.add_theme_stylebox_override("panel", _inventory_icon_style)
	root.add_child(_inventory_icon)

	var sticker_shine := ColorRect.new()
	sticker_shine.position = Vector2(10, 9)
	sticker_shine.size = Vector2(18, 10)
	sticker_shine.color = Color(1, 1, 1, 0.42)
	sticker_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_icon.add_child(sticker_shine)

	_inventory_count = Label.new()
	_inventory_count.name = "InventoryCount"
	_inventory_count.position = Vector2(84, 8)
	_inventory_count.size = Vector2(104, 54)
	_inventory_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inventory_count.add_theme_font_size_override("font_size", 38)
	_inventory_count.add_theme_color_override("font_color", INK)
	_inventory_count.add_theme_color_override("font_outline_color", CREAM)
	_inventory_count.add_theme_constant_override("outline_size", 4)
	_inventory_count.text = "× 0"
	var count_font := FontVariation.new()
	if font != null:
		count_font.base_font = font
	count_font.variation_embolden = 0.9
	_inventory_count.add_theme_font_override("font", count_font)
	root.add_child(_inventory_count)

	var caption := Label.new()
	caption.name = "InventoryCaption"
	caption.position = Vector2(88, 64)
	caption.size = Vector2(96, 24)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", SOFT_TEXT)
	caption.text = "积木"
	if font != null:
		caption.add_theme_font_override("font", font)
	root.add_child(caption)


func _refresh_inventory(stage: int, charges: int) -> void:
	if _inventory_count == null:
		return
	var color := MAGENTA
	if stage == 1:
		color = CYAN
	elif stage >= 2:
		color = PURPLE
	if charges <= 0:
		color = Color(0.62, 0.61, 0.63)
	if _inventory_icon_style != null:
		_inventory_icon_style.bg_color = color
	_inventory_count.text = "× %d" % charges
	_inventory_count.add_theme_color_override("font_color", INK if charges > 0 else Color(0.55, 0.54, 0.56))
	if charges != _inventory_value:
		_inventory_value = charges
		_inventory_count.pivot_offset = _inventory_count.size * 0.5
		_inventory_count.scale = Vector2(1.22, 1.22)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(_inventory_count, "scale", Vector2.ONE, 0.28)


## 左侧第二块贴纸：吃到的球数量，和积木库存同款。
func _build_orb_inventory() -> void:
	var root := Control.new()
	root.name = "OrbInventory"
	root.position = Vector2(22, 342)
	root.size = Vector2(196, 118)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_orb_panel = Panel.new()
	_orb_panel.name = "OrbInventoryPanel"
	_orb_panel.position = Vector2.ZERO
	_orb_panel.size = Vector2(196, 118)
	_orb_panel.add_theme_stylebox_override(
		"panel", _soft_style(22, Color(0.98, 0.97, 0.98, 0.93), SOFT_BORDER, 2)
	)
	_orb_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_orb_panel)

	_orb_icon = Panel.new()
	_orb_icon.name = "OrbSticker"
	_orb_icon.position = Vector2(14, 28)
	_orb_icon.size = Vector2(62, 62)
	_orb_icon.pivot_offset = _orb_icon.size * 0.5
	_orb_icon.rotation = deg_to_rad(-4.0)
	_orb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_icon_style = StyleBoxFlat.new()
	_orb_icon_style.bg_color = Color(0.62, 0.61, 0.63)
	_orb_icon_style.border_color = Color(1, 1, 1, 0.95)
	_orb_icon_style.set_border_width_all(4)
	_orb_icon_style.set_corner_radius_all(31)
	_orb_icon_style.shadow_color = Color(0.24, 0.20, 0.30, 0.18)
	_orb_icon_style.shadow_size = 6
	_orb_icon_style.shadow_offset = Vector2(0, 4)
	_orb_icon.add_theme_stylebox_override("panel", _orb_icon_style)
	root.add_child(_orb_icon)

	var sticker_shine := ColorRect.new()
	sticker_shine.position = Vector2(14, 10)
	sticker_shine.size = Vector2(16, 9)
	sticker_shine.color = Color(1, 1, 1, 0.42)
	sticker_shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_icon.add_child(sticker_shine)

	_orb_count = Label.new()
	_orb_count.name = "OrbCount"
	_orb_count.position = Vector2(84, 8)
	_orb_count.size = Vector2(104, 54)
	_orb_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orb_count.add_theme_font_size_override("font_size", 38)
	_orb_count.add_theme_color_override("font_color", Color(0.55, 0.54, 0.56))
	_orb_count.add_theme_color_override("font_outline_color", CREAM)
	_orb_count.add_theme_constant_override("outline_size", 4)
	_orb_count.text = "× 0"
	var count_font := FontVariation.new()
	if font != null:
		count_font.base_font = font
	count_font.variation_embolden = 0.9
	_orb_count.add_theme_font_override("font", count_font)
	root.add_child(_orb_count)

	var caption := Label.new()
	caption.name = "OrbCaption"
	caption.position = Vector2(88, 64)
	caption.size = Vector2(96, 24)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 16)
	caption.add_theme_color_override("font_color", SOFT_TEXT)
	caption.text = "球"
	if font != null:
		caption.add_theme_font_override("font", font)
	root.add_child(caption)


func _refresh_orb_inventory(orbs: int) -> void:
	if _orb_count == null:
		return
	var color := Color(0.62, 0.61, 0.63)
	if orbs == 1:
		color = Color(1.0, 0.72, 0.18)
	elif orbs >= 2:
		color = CYAN
	if _orb_icon_style != null:
		_orb_icon_style.bg_color = color
	_orb_count.text = "× %d" % orbs
	_orb_count.add_theme_color_override("font_color", INK if orbs > 0 else Color(0.55, 0.54, 0.56))
	if orbs != _orb_value:
		_orb_value = orbs
		_orb_count.pivot_offset = _orb_count.size * 0.5
		_orb_count.scale = Vector2(1.22, 1.22)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_BACK)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(_orb_count, "scale", Vector2.ONE, 0.28)


func _build_crush_panel() -> void:
	_crush_panel = Control.new()
	_crush_panel.name = "CrushPanel"
	_crush_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crush_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_crush_panel.visible = false
	add_child(_crush_panel)

	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.09, 0.12, 0.38)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_crush_panel.add_child(dim)

	var card := Panel.new()
	card.size = Vector2(520, 280)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.position = Vector2(-260, -140)
	card.add_theme_stylebox_override(
		"panel", _soft_style(26, Color(1, 1, 1, 0.98), SOFT_BORDER, 3)
	)
	_crush_panel.add_child(card)

	var title := Label.new()
	title.text = "被砸中了"
	title.position = Vector2(40, 34)
	title.size = Vector2(440, 48)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", MAGENTA)
	if font != null:
		title.add_theme_font_override("font", font)
	card.add_child(title)

	var body := Label.new()
	body.text = "是否重新开始本关？"
	body.position = Vector2(40, 96)
	body.size = Vector2(440, 40)
	body.add_theme_font_size_override("font_size", 21)
	body.add_theme_color_override("font_color", INK)
	if font != null:
		body.add_theme_font_override("font", font)
	card.add_child(body)

	var confirm := Button.new()
	confirm.text = "确认"
	confirm.position = Vector2(40, 190)
	confirm.size = Vector2(190, 52)
	confirm.focus_mode = Control.FOCUS_NONE
	_style_button(confirm)
	confirm.pressed.connect(_on_crush_confirm)
	card.add_child(confirm)

	var leave := Button.new()
	leave.text = "离开"
	leave.position = Vector2(290, 190)
	leave.size = Vector2(190, 52)
	leave.focus_mode = Control.FOCUS_NONE
	_style_button(leave)
	leave.pressed.connect(_on_crush_leave)
	card.add_child(leave)


func _on_player_crushed() -> void:
	if _crush_panel != null:
		_crush_panel.visible = true


func _on_crush_confirm() -> void:
	if _crush_panel != null:
		_crush_panel.visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_crush_leave() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://theme_d/level_select.tscn")


func _soft_style(radius: int, bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.shadow_color = Color(0.24, 0.20, 0.30, 0.13)
	sb.shadow_size = 14
	sb.shadow_offset = Vector2(0, 6)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _build_menu_buttons() -> void:
	var menu := Button.new()
	menu.name = "MainMenuButton"
	menu.text = "主菜单"
	menu.position = Vector2(24, 22)
	menu.size = Vector2(132, 42)
	menu.focus_mode = Control.FOCUS_NONE
	_style_button(menu)
	menu.pressed.connect(_on_main_menu_pressed)
	add_child(menu)

	var reset := Button.new()
	reset.name = "ResetButton"
	reset.text = "重置关卡"
	reset.position = Vector2(168, 22)
	reset.size = Vector2(132, 42)
	reset.focus_mode = Control.FOCUS_NONE
	_style_button(reset)
	reset.pressed.connect(_on_reset_pressed)
	add_child(reset)

	_undo_button = Button.new()
	_undo_button.name = "UndoButton"
	_undo_button.text = "收回最后一块"
	_undo_button.position = Vector2(312, 22)
	_undo_button.size = Vector2(150, 42)
	_undo_button.focus_mode = Control.FOCUS_NONE
	_style_button(_undo_button)
	_undo_button.disabled = true
	_undo_button.pressed.connect(_on_undo_pressed)
	add_child(_undo_button)



func _style_button(btn: Button) -> void:
	if font != null:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 19)
	btn.add_theme_color_override("font_color", INK)
	btn.add_theme_color_override("font_hover_color", INK)
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1))

	var normal := _soft_style(14, Color(1, 1, 1, 0.96), SOFT_BORDER, 2)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(1.0, 0.96, 0.98)
	hover.border_color = MAGENTA
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = MAGENTA
	pressed.border_color = MAGENTA
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled_box := normal.duplicate() as StyleBoxFlat
	disabled_box.bg_color = Color(0.94, 0.94, 0.94)
	disabled_box.border_color = Color(0.86, 0.86, 0.86)
	disabled_box.shadow_size = 0
	btn.add_theme_stylebox_override("disabled", disabled_box)
	btn.add_theme_color_override("font_disabled_color", Color(0.62, 0.61, 0.63))


func _refresh_status() -> void:
	if cube == null or not is_instance_valid(cube):
		return
	var state: Dictionary = cube.call("get_build_state")
	var stage := int(state.get("stage", 0))
	var charges := int(state.get("charges", 0))
	var orbs := int(state.get("orbs_collected", 0))
	_refresh_inventory(stage, charges)
	_refresh_orb_inventory(orbs)


func _on_flip_blocked(reason: String = "") -> void:
	if _flip_toast_cooldown > 0.0:
		return
	_flip_toast_cooldown = 2.5
	if reason == "":
		reason = "这一面翻不动：看看墙脚是不是被固定块/积木挡住了。"
	_show_toast(reason)


func _on_build_refused(reason: String) -> void:
	_show_toast(reason)


func _on_orb_collected(index: int, blocks: int, next_face: String) -> void:
	if index == 0:
		_show_toast("金色球：+%d 块。把金框的 %s 面翻成底面，青色球会亮起。" % [blocks, next_face])
	else:
		_show_toast("青色球：+%d 块。第二段：1 米 + 2 米垫在 3 米软糖下，R 面落块压上去，再翻 %s 面。" % [blocks, next_face])


func _on_exit_activated() -> void:
	_show_toast("L 面成了底面：出口打开了。爬 1→2→3→4 米连续塔，从 4 米跳进去。")


func _on_undo_pressed() -> void:
	if cube != null:
		cube.call("undo_last_block")
		_refresh_undo_button()


func _show_toast(text: String) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.visible = true
	if _toast_panel != null:
		_toast_panel.visible = true
	_toast_time = 1.6


# ---------------------------------------------------------------- 胜利界面

func _build_win_panel() -> void:
	_win = Control.new()
	_win.name = "WinPanel"
	_win.mouse_filter = Control.MOUSE_FILTER_STOP
	_win.visible = false
	add_child(_win)
	_win.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.96, 0.95, 0.96, 0.66)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_win.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	_win.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 380)
	var sb := _soft_style(24, Color(1, 1, 1, 0.99), Color(0.93, 0.92, 0.91), 2)
	sb.shadow_size = 22
	sb.shadow_offset = Vector2(0, 10)
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 0)
	vbox.add_child(bars)
	for c in [MAGENTA, CYAN, PURPLE]:
		var bar := ColorRect.new()
		bar.color = c
		bar.custom_minimum_size = Vector2(0, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bars.add_child(bar)

	var title := Label.new()
	title.text = "禅面造阶 · 软糖通关"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", INK)
	if font != null:
		title.add_theme_font_override("font", font)
	vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "你把金框 B 面翻成底面让青球亮起，再把蓝框 L 面翻成底面打开出口。第一段把 3 块咬在 B 面固定软糖上，接成 1→2→3 米台阶；第二段把 1 米 + 2 米垫在 3 米软糖下，R 面落块压在上面，形成 1→2→3→4 米连续塔，你从 4 米跳进 5.5 米出口。"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color(0.18, 0.18, 0.18))
	if font != null:
		subtitle.add_theme_font_override("font", font)
	vbox.add_child(subtitle)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var again := Button.new()
	again.text = "再玩一次"
	again.custom_minimum_size = Vector2(170, 48)
	again.focus_mode = Control.FOCUS_NONE
	_style_button(again)
	again.pressed.connect(_on_reset_pressed)
	row.add_child(again)

	var menu_btn := Button.new()
	menu_btn.text = "返回主菜单"
	menu_btn.custom_minimum_size = Vector2(170, 48)
	menu_btn.focus_mode = Control.FOCUS_NONE
	_style_button(menu_btn)
	menu_btn.pressed.connect(_on_main_menu_pressed)
	row.add_child(menu_btn)


## portal_absorb.gd 通过 call_group("ui_ingame", "show_win_after_absorb") 调用。
func show_win_after_absorb() -> void:
	if _won:
		return
	_won = true
	if _win != null:
		_win.visible = true
		_win.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func _on_main_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://theme_d/level_select.tscn")


func _on_reset_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
