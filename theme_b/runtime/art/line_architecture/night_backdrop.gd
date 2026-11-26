extends Node3D
func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://theme_b/runtime/art/line_architecture/night_backdrop.gdshader")
	rect.material = mat
	layer.add_child(rect)
	var world := get_node("WorldEnvironment") as WorldEnvironment
	world.environment.background_mode = Environment.BG_CANVAS
	world.environment.background_canvas_max_layer = -100
