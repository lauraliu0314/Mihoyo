extends Node

## 第六关软糖工作室环境：近白墙面、极淡接缝、白玻璃软糖物块。
## 角色、玩法积木、球、提示仍然保持高对比可读。

const WALL_SHADER := preload("res://theme_d/level6/studio_wall.gdshader")
const BG_SHADER := preload("res://theme_d/level6/studio_background.gdshader")

## 六面各给一点粉彩 tint，纯白环境里也能分辨方位。
const FACE_TINTS := [
	Color(1.00, 0.90, 0.92),
	Color(1.00, 0.95, 0.86),
	Color(0.88, 0.98, 0.94),
	Color(0.88, 0.94, 1.00),
	Color(0.94, 0.90, 1.00),
	Color(1.00, 0.98, 0.88),
]


func _ready() -> void:
	var main := get_parent()
	_style_walls(main)
	_style_background(main)
	_style_environment(main)
	_style_floor_grid(main)


func _style_walls(main: Node) -> void:
	var walls := main.get_node_or_null("Node3D/WALLS")
	if walls == null:
		return
	var face_index := 0
	for wall in walls.get_children():
		for child in wall.get_children():
			var mesh := child as MeshInstance3D
			if mesh == null:
				continue
			var mat := ShaderMaterial.new()
			mat.shader = WALL_SHADER
			mat.set_shader_parameter("face_id", face_index)
			mat.set_shader_parameter("grid_count", 6.0)
			var tint: Color = FACE_TINTS[face_index % FACE_TINTS.size()]
			mat.set_shader_parameter("tint", tint)
			mesh.material_override = mat
		face_index += 1


func _style_background(main: Node) -> void:
	var bg := main.get_node_or_null("LevelEnvironment/BG_Space") as MeshInstance3D
	if bg != null:
		var mat := ShaderMaterial.new()
		mat.shader = BG_SHADER
		bg.material_override = mat
	var meteor := main.get_node_or_null("LevelEnvironment/MeteorSpawner") as Node3D
	if meteor != null:
		meteor.visible = false


func _style_environment(main: Node) -> void:
	var we := main.get_node_or_null("LevelEnvironment/WorldEnvironment") as WorldEnvironment
	if we != null and we.environment != null:
		var env := we.environment.duplicate() as Environment
		if env != null:
			env.background_mode = Environment.BG_COLOR
			env.background_color = Color(0.56, 0.57, 0.60)
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(1.0, 0.985, 0.965)
			env.ambient_light_energy = 0.25
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.tonemap_exposure = 0.94
			env.tonemap_white = 1.0
			env.ssao_enabled = true
			env.ssao_radius = 1.6
			env.ssao_intensity = 1.5
			we.environment = env
	var key := main.get_node_or_null("LevelEnvironment/KeyLight") as OmniLight3D
	if key != null:
		key.light_color = Color(1.0, 0.975, 0.94)
		key.light_energy = 0.28
		key.shadow_opacity = 0.80
		key.omni_range = 9.0
	var sun := main.get_node_or_null("StudioSun") as DirectionalLight3D
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "StudioSun"
		main.add_child.call_deferred(sun)
	sun.light_color = Color(1.0, 0.98, 0.95)
	sun.light_energy = 0.58
	sun.rotation_degrees = Vector3(-52, -32, 0)
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.85
	sun.directional_shadow_max_distance = 20.0


func _style_floor_grid(main: Node) -> void:
	var grid := main.get_node_or_null("Node3D/FloorGrid")
	if grid == null:
		return
	for child in grid.get_children():
		var mesh := child as MeshInstance3D
		if mesh == null:
			continue
		var base := mesh.material_override as StandardMaterial3D
		if base == null:
			continue
		var mat := base.duplicate() as StandardMaterial3D
		mat.albedo_color = Color(0.35, 0.35, 0.36, 0.22)
		mesh.material_override = mat
