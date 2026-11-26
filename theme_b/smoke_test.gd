extends SceneTree
func _initialize() -> void:
	run.call_deferred()
func run() -> void:
	for level in ["tutorial", "level1", "level2", "level3"]:
		var scene: Node = load("res://theme_b/%s/main.tscn" % level).instantiate()
		root.add_child(scene)
		current_scene = scene
		for frame in range(24):
			await process_frame
		assert(get_node_progress() != null)
		var manager := scene.get_node("ConstructionManager")
		assert(manager.burn_timer_enabled == (level != "tutorial"))
		assert(not scene.find_children("LineArchitecture", "MeshInstance3D", true, false).is_empty())
		if level == "tutorial":
			var tools := scene.get_node("Node3D/Tool_B_D_G")
			assert(tools.get_node_or_null("B_Tool") == null)
			assert(tools.get_node_or_null("D_Wall") == null)
			var final_key := scene.get_node("Node3D/FinalKey")
			assert(not final_key.can_press_button())
			tools.get_node("G_Tool").g_collected.emit()
			assert(final_key.can_press_button())
		print("PASS theme_b/", level)
		scene.queue_free()
		await process_frame
	var menu: Node = load("res://theme_b/level_select.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	print("PASS theme_b/level_select")
	quit()
func get_node_progress() -> Node:
	return root.get_node_or_null("ThemeBProgress")
