extends Node

## Black-and-white level look. Only the current scene instance is changed.

const _WALL_SHADER := preload("res://assets/decon/decon_wall.gdshader")
const _STYLE := preload("res://assets/decon/decon_style.gd")

var _wall_material: ShaderMaterial
var _cube: Node3D


func _ready() -> void:
	_apply_environment()
	_apply_walls()
	_desaturate_controls(self)


func _apply_environment() -> void:
	var env_root := get_node_or_null("LevelEnvironment")
	if env_root == null:
		return
	var world := env_root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world != null and world.environment != null:
		var env := world.environment.duplicate(true) as Environment
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.06, 0.06, 0.06)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.267, 0.267, 0.267)
		env.ambient_light_energy = 1.0
		env.adjustment_enabled = false
		world.environment = env
	var backdrop := env_root.get_node_or_null("BG_Space") as Node3D
	if backdrop != null:
		backdrop.visible = false


func _apply_walls() -> void:
	var walls := get_node_or_null("Node3D/WALLS")
	if walls == null:
		return
	var material := ShaderMaterial.new()
	material.shader = _WALL_SHADER
	_STYLE.load_default().apply_wall(material)
	_wall_material = material
	_cube = get_node_or_null("Node3D") as Node3D
	_sync_room_center()
	for child in walls.get_children():
		var mesh := child.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh != null:
			mesh.material_override = material


func _process(_delta: float) -> void:
	_sync_room_center()


func _sync_room_center() -> void:
	if _wall_material == null or _cube == null:
		return
	_wall_material.set_shader_parameter("room_center", _cube.to_global(Vector3(0.0, 3.0, 0.0)))


func _desaturate_controls(node: Node) -> void:
	if node is Control:
		_desaturate_control(node as Control)
	for child in node.get_children():
		_desaturate_controls(child)


func _desaturate_control(control: Control) -> void:
	var modulate := control.modulate
	if modulate != Color.WHITE:
		control.modulate = _gray(modulate)
	for color_name in [
		"font_color",
		"font_hover_color",
		"font_pressed_color",
		"font_disabled_color",
		"font_shadow_color",
		"font_outline_color",
		"font_focus_color",
	]:
		if control.has_theme_color_override(color_name):
			control.add_theme_color_override(color_name, _gray(control.get_theme_color(color_name)))
	for style_name in ["panel", "normal", "hover", "pressed", "disabled", "focus"]:
		if not control.has_theme_stylebox_override(style_name):
			continue
		var style := control.get_theme_stylebox(style_name)
		if not (style is StyleBoxFlat):
			continue
		var flat := (style as StyleBoxFlat).duplicate() as StyleBoxFlat
		flat.bg_color = _gray(flat.bg_color)
		flat.border_color = _gray(flat.border_color)
		flat.shadow_color = _gray(flat.shadow_color)
		control.add_theme_stylebox_override(style_name, flat)


func _gray(color: Color) -> Color:
	var luma := color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722
	return Color(luma, luma, luma, color.a)
