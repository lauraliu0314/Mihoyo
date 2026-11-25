extends Node3D

## Run this scene with F6. Sliders preview locally. Save writes decon_style.tres for all three levels.

const _WALL_SHADER := preload("res://assets/decon/decon_wall.gdshader")
const _BLOCK_SCENE := preload("res://assets/decon/decon_block.tscn")
const _STYLE := preload("res://assets/decon/decon_style.gd")
const _STYLE_PATH := "res://assets/decon/decon_style.tres"

const _WALL_FIELDS := [
	["wall_blur", "模糊", 0.0, 1.0, 0.01],
	["wall_sharpness", "锐度", 0.0, 1.0, 0.01],
	["wall_grain", "颗粒", 0.0, 1.0, 0.01],
	["wall_brightness", "亮度", 0.0, 1.0, 0.01],
	["seam", "墙缝", 0.0, 1.0, 0.01],
	["wall_hue", "色相", -1.0, 1.0, 0.01],
]
const _BLOCK_FIELDS := [
	["block_blur", "模糊", 0.0, 1.0, 0.01],
	["block_sharpness", "锐度", 0.0, 1.0, 0.01],
	["block_grain", "颗粒", 0.0, 1.0, 0.01],
	["transmit", "透光", 0.0, 1.0, 0.01],
	["roundness", "圆角", 0.0, 1.0, 0.01],
	["gap", "缝隙", 0.0, 0.2, 0.001],
	["face_contrast", "三面对比", 0.0, 1.0, 0.01],
	["block_hue", "色相", -1.0, 1.0, 0.01],
]
const _LIGHT_FIELDS := [
	["light_yaw", "左右", -1.0, 1.0, 0.01],
	["light_pitch", "高低", -1.0, 1.0, 0.01],
	["light_strength", "强度", 0.0, 1.0, 0.01],
	["light_fill", "暗部", 0.0, 1.0, 0.01],
	["light_hue", "光色", -1.0, 1.0, 0.01],
]

const _SUN_CENTER := Vector3(0.0, 3.0, 0.0)
const _SUN_DISTANCE := 6.5

var _style
var _saved
var _status: Label
var _camera: Camera3D
var _sun: MeshInstance3D
var _sun_beam: MeshInstance3D
var _dragging_sun := false
var _sliders := {}
var _slider_labels := {}
var _wall_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 800))
	_saved = _STYLE.load_default()
	_style = _saved.duplicate()
	_build_room()
	_build_blocks()
	_build_panel()
	_place_sun()


func _build_room() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.06, 0.06, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.267, 0.267, 0.267)
	env.ambient_light_energy = 1.0
	env.adjustment_enabled = false
	world.environment = env
	add_child(world)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 11.0
	_camera.position = Vector3(-8.0, 9.0, 8.0)
	add_child(_camera)
	_camera.look_at(Vector3(0.0, 2.0, 0.0))
	_build_sun()
	_add_wall(Vector3(0, 0, 0), Vector3.ZERO)
	_add_wall(Vector3(3, 3, 0), Vector3(0, 0, -90))
	_add_wall(Vector3(0, 3, -3), Vector3(90, 0, 0))


func _add_wall(pos: Vector3, rot_degrees: Vector3) -> void:
	var mesh_node := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(6, 6)
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.rotation_degrees = rot_degrees
	var mat := ShaderMaterial.new()
	mat.shader = _WALL_SHADER
	_style.apply_wall(mat)
	mesh_node.material_override = mat
	_wall_materials.append(mat)
	add_child(mesh_node)


func _build_blocks() -> void:
	for x in [-0.5, 0.5, 1.5]:
		for z in [-0.5, 0.5, 1.5]:
			_add_block(Vector3(x, 0.5, z))
	for y in [1.5, 2.5, 3.5]:
		_add_block(Vector3(2.5, y, 0.5))


func _add_block(pos: Vector3) -> void:
	var block := _BLOCK_SCENE.instantiate() as Node3D
	block.position = pos
	add_child(block)


func _build_panel() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	panel.offset_left = -300.0
	panel.offset_top = 16.0
	panel.offset_right = -16.0
	panel.offset_bottom = -16.0
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.12, 0.12, 0.12, 0.92)
	flat.content_margin_left = 16.0
	flat.content_margin_right = 16.0
	flat.content_margin_top = 16.0
	flat.content_margin_bottom = 16.0
	panel.add_theme_stylebox_override("panel", flat)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(box)
	var title := Label.new()
	title.text = "方块外观"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "在画面空白处按住拖动来摆光。透光 0 是实心。点保存后，三个关卡下次启动一起使用。"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	box.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var fields := VBoxContainer.new()
	fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fields.add_theme_constant_override("separation", 8)
	scroll.add_child(fields)
	fields.add_child(_section_title("打光"))
	for field in _LIGHT_FIELDS:
		fields.add_child(_make_slider(field))
	fields.add_child(_section_title("背景墙面"))
	for field in _WALL_FIELDS:
		fields.add_child(_make_slider(field))
	fields.add_child(_section_title("小方块"))
	for field in _BLOCK_FIELDS:
		fields.add_child(_make_slider(field))
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_status.text = "尚未保存"
	box.add_child(_status)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	box.add_child(buttons)
	buttons.add_child(_make_button("保存", _save))
	buttons.add_child(_make_button("退出", _exit))


func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	return label


func _make_slider(field: Array) -> Control:
	var prop: String = field[0]
	var title: String = field[1]
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	var label := Label.new()
	label.add_theme_color_override("font_color", Color.WHITE)
	var current: float = _style.get(prop)
	label.text = "%s  %.3f" % [title, current]
	label.set_meta("title", title)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = field[2]
	slider.max_value = field[3]
	slider.step = field[4]
	slider.value = current
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size = Vector2(0, 22)
	_sliders[prop] = slider
	_slider_labels[prop] = label
	slider.value_changed.connect(func(value: float) -> void:
		_style.set(prop, value)
		label.text = "%s  %.3f" % [title, value]
		_preview()
		_status.text = "尚未保存"
	)
	row.add_child(slider)
	return row


func _make_button(title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0, 36)
	button.pressed.connect(callback)
	return button


func _preview() -> void:
	for mat in _wall_materials:
		_style.apply_wall(mat)
	for node in get_tree().get_nodes_in_group("decon_block"):
		if node.has_method("apply_from_style"):
			node.apply_from_style(_style)
	_place_sun()


func _build_sun() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.82, 0.45)
	_sun = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.42
	ball.height = 0.84
	_sun.mesh = ball
	_sun.material_override = mat
	add_child(_sun)
	_sun_beam = MeshInstance3D.new()
	var beam := CylinderMesh.new()
	beam.top_radius = 0.05
	beam.bottom_radius = 0.05
	beam.height = _SUN_DISTANCE
	_sun_beam.mesh = beam
	var beam_mat := mat.duplicate() as StandardMaterial3D
	beam_mat.albedo_color = Color(1.0, 0.82, 0.45, 0.45)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sun_beam.material_override = beam_mat
	add_child(_sun_beam)


func _sun_direction() -> Vector3:
	var yaw := float(_style.light_yaw) * PI
	var pitch := float(_style.light_pitch) * PI * 0.5
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)).normalized()


func _place_sun() -> void:
	if _sun == null:
		return
	var dir := _sun_direction()
	_sun.position = _SUN_CENTER + dir * _SUN_DISTANCE
	_sun_beam.position = _SUN_CENTER + dir * (_SUN_DISTANCE * 0.5)
	var x := dir.cross(Vector3.FORWARD)
	if x.length_squared() < 0.0001:
		x = Vector3.RIGHT
	x = x.normalized()
	var z := x.cross(dir).normalized()
	_sun_beam.basis = Basis(x, dir, z)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_dragging_sun = true
		_drag_sun(event.position)
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _dragging_sun:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_dragging_sun = false
	elif event is InputEventMouseMotion:
		_drag_sun(event.position)


func _drag_sun(screen: Vector2) -> void:
	var origin := _camera.project_ray_origin(screen)
	var dir := _camera.project_ray_normal(screen)
	var point: Variant = _ray_sphere(origin, dir, _SUN_CENTER, _SUN_DISTANCE)
	if point == null:
		var closest := origin + dir * (_SUN_CENTER - origin).dot(dir)
		var outward := closest - _SUN_CENTER
		if outward.length_squared() < 0.0001:
			return
		point = _SUN_CENTER + outward.normalized() * _SUN_DISTANCE
	var sun_dir := ((point as Vector3) - _SUN_CENTER).normalized()
	_style.light_pitch = clampf(asin(clampf(sun_dir.y, -1.0, 1.0)) / (PI * 0.5), -1.0, 1.0)
	_style.light_yaw = clampf(atan2(sun_dir.x, sun_dir.z) / PI, -1.0, 1.0)
	for prop in ["light_yaw", "light_pitch"]:
		var value: float = _style.get(prop)
		(_sliders[prop] as HSlider).set_value_no_signal(value)
		var label := _slider_labels[prop] as Label
		label.text = "%s  %.3f" % [label.get_meta("title"), value]
	_preview()
	_status.text = "尚未保存"


func _ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> Variant:
	var offset := origin - center
	var b := offset.dot(dir)
	var h := b * b - (offset.dot(offset) - radius * radius)
	if h < 0.0:
		return null
	var t := -b - sqrt(h)
	if t < 0.0:
		t = -b + sqrt(h)
	if t < 0.0:
		return null
	return origin + dir * t


func _save() -> void:
	for field in _WALL_FIELDS:
		_saved.set(field[0], _style.get(field[0]))
	for field in _BLOCK_FIELDS:
		_saved.set(field[0], _style.get(field[0]))
	for field in _LIGHT_FIELDS:
		_saved.set(field[0], _style.get(field[0]))
	if _saved.resource_path.is_empty():
		_saved.take_over_path(_STYLE_PATH)
	var err := ResourceSaver.save(_saved, _STYLE_PATH)
	if err == OK:
		_status.text = "已保存，三个关卡下次启动生效"
	else:
		_status.text = "保存失败"


func _exit() -> void:
	get_tree().quit()
