extends Node3D

func _enter_tree() -> void:
	_install_theme_runtime.call_deferred()

func _install_theme_runtime() -> void:
	if get_node_or_null("/root/ThemeBProgress") == null:
		var progress := Node.new()
		progress.name = "ThemeBProgress"
		progress.set_script(preload("res://theme_b/progress.gd"))
		get_tree().root.add_child(progress)
	var style := Node.new()
	style.name = "ThemeBArchitecture"
	style.set_script(preload("res://theme_b/runtime/art/line_architecture/block_style.gd"))
	add_child(style)
