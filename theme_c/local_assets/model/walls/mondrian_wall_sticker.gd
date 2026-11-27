@tool
extends Node3D

## One editable inner-face tile. The parent is the unique cubie at this grid cell.
@export_enum("White", "Red", "Yellow", "Blue", "Black") var color_state: int = 0:
	set(value):
		color_state = clampi(value, 0, 4)
		_apply_material()
		_request_layout()

## Left, right, top, bottom. A marked edge keeps a line even beside the same color.
@export_flags("Left", "Right", "Top", "Bottom") var force_edges: int = 0:
	set(value):
		force_edges = value
		_request_layout()

@export var is_hole: bool = false:
	set(value):
		is_hole = value
		_apply_material()
		_request_layout()

const PALETTE := [
	preload("res://theme_c/local_assets/model/walls/mondrian_white.tres"),
	preload("res://theme_c/local_assets/model/walls/mondrian_red.tres"),
	preload("res://theme_c/local_assets/model/walls/mondrian_yellow.tres"),
	preload("res://theme_c/local_assets/model/walls/mondrian_blue.tres"),
	preload("res://theme_c/local_assets/model/walls/mondrian_black.tres"),
]


func _ready() -> void:
	_apply_material()


func _apply_material() -> void:
	var panel := get_node_or_null("Color") as MeshInstance3D
	if panel != null:
		panel.material_override = PALETTE[color_state]
		panel.visible = not is_hole
	var frame := get_node_or_null("Frame") as MeshInstance3D
	if frame != null:
		frame.visible = not is_hole


func set_edge_gaps(left: float, right: float, top: float, bottom: float) -> void:
	var panel := get_node_or_null("Color") as MeshInstance3D
	if panel == null:
		return
	panel.scale = Vector3(1.0 - left - right, 1.0 - top - bottom, 1.0)
	panel.position = Vector3((left - right) * 0.5, (bottom - top) * 0.5, 0.004)


func _request_layout() -> void:
	if not is_inside_tree() or not Engine.is_editor_hint():
		return
	var cubie := get_parent()
	if cubie != null and cubie.get_parent() != null:
		var root := cubie.get_parent()
		if root.has_method("refresh_layout"):
			root.call_deferred("refresh_layout")
