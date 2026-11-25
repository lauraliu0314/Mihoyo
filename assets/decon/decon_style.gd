extends Resource

## Shared frosted-cube look. Edit this resource, or run decon_preview.tscn and use the sliders.
## Levels read res://assets/decon/decon_style.tres when they start.
## The preview scene writes this file only when Save is pressed.

const PATH := "res://assets/decon/decon_style.tres"

@export_range(0.0, 1.0, 0.01) var wall_blur: float = 0.0
@export_range(0.0, 1.0, 0.01) var wall_sharpness: float = 0.83
@export_range(0.0, 1.0, 0.01) var wall_grain: float = 1.0
@export_range(0.0, 1.0, 0.01) var wall_brightness: float = 0.61
@export_range(0.0, 1.0, 0.01) var seam: float = 0.24
@export_range(0.0, 1.0, 0.01) var block_blur: float = 0.0
@export_range(0.0, 1.0, 0.01) var block_sharpness: float = 0.83
@export_range(0.0, 1.0, 0.01) var block_grain: float = 1.0
@export_range(0.0, 1.0, 0.01) var transmit: float = 0.0
@export_range(0.0, 1.0, 0.01) var roundness: float = 0.45
@export_range(0.0, 0.2, 0.001) var gap: float = 0.103
@export_range(0.0, 1.0, 0.01) var face_contrast: float = 1.0
@export_range(-1.0, 1.0, 0.01) var wall_hue: float = 0.45
@export_range(-1.0, 1.0, 0.01) var block_hue: float = -0.45
@export_range(-1.0, 1.0, 0.01) var light_yaw: float = 0.16
@export_range(-1.0, 1.0, 0.01) var light_pitch: float = 0.21
@export_range(0.0, 1.0, 0.01) var light_strength: float = 0.7
@export_range(0.0, 1.0, 0.01) var light_fill: float = 0.32
@export_range(-1.0, 1.0, 0.01) var light_hue: float = 0.6


static func load_default() -> Resource:
	var loaded = load(PATH)
	if loaded != null and loaded.has_method("visual_scale"):
		return loaded
	return (load("res://assets/decon/decon_style.gd") as GDScript).new()


func visual_scale() -> float:
	return 1.0 - clampf(gap, 0.0, 0.2)


func apply_wall(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("blur", wall_blur)
	mat.set_shader_parameter("sharpness", wall_sharpness)
	mat.set_shader_parameter("grain", wall_grain)
	mat.set_shader_parameter("wall_brightness", wall_brightness)
	mat.set_shader_parameter("seam_width", clampf(seam, 0.0, 1.0) * 0.08)
	var keep := 1.0 - clampf(seam * (0.22 / 0.15), 0.0, 0.85)
	mat.set_shader_parameter("seam_keep", keep)
	mat.set_shader_parameter("hue", wall_hue)
	mat.set_shader_parameter("room_center", Vector3(0.0, 3.0, 0.0))
	_apply_light(mat)


func apply_block(mat: ShaderMaterial, shade_value: float, face_axis: Vector3, side_axis: Vector3) -> void:
	mat.set_shader_parameter("shade", shade_value)
	mat.set_shader_parameter("face_axis", face_axis)
	mat.set_shader_parameter("side_axis", side_axis)
	mat.set_shader_parameter("blur", block_blur)
	mat.set_shader_parameter("transmit", transmit)
	mat.set_shader_parameter("roundness", roundness)
	mat.set_shader_parameter("sharpness", block_sharpness)
	mat.set_shader_parameter("grain", block_grain)
	mat.set_shader_parameter("face_contrast", face_contrast)
	mat.set_shader_parameter("hue", block_hue)
	_apply_light(mat)


func _apply_light(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("light_yaw", light_yaw)
	mat.set_shader_parameter("light_pitch", light_pitch)
	mat.set_shader_parameter("light_strength", light_strength)
	mat.set_shader_parameter("light_fill", light_fill)
	mat.set_shader_parameter("light_hue", light_hue)
