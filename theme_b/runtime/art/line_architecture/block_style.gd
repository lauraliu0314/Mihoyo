extends Node
## Applies to authored and runtime-created blocks, leaving physics untouched.
var mesh_cache: Dictionary = {}
var materials: Dictionary = {}
const RIBBON = preload("res://theme_b/runtime/art/line_architecture/light_ribbons.gdshader")
const HALO = preload("res://theme_b/runtime/art/line_architecture/soft_halo.gdshader")

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred(get_tree().root)

func _on_node_added(node: Node) -> void:
	if node is Node3D:
		_abstract_prop.call_deferred(node)
	if node is MeshInstance3D:
		_fluorescent.call_deferred(node)
	if node is Light3D or node is WorldEnvironment:
		_style.call_deferred(node)
	if node is PhysicsBody3D:
		_style.call_deferred(node)
	elif node is CollisionShape3D:
		_style.call_deferred(node.get_parent())

func _scan(node: Node) -> void:
	_abstract_prop(node)
	_style(node)
	if node is MeshInstance3D:
		_fluorescent(node)
	for child in node.get_children():
		_scan(child)

func _abstract_prop(node: Node) -> void:
	if not is_instance_valid(node) or not node is Node3D or node.has_meta("abstract_visual"):
		return
	if node.name == "CageVisual":
		_hide_original(node)
		return
	var identity := node.scene_file_path.to_lower()
	var kind := ""
	if identity.ends_with("pizza_slice.tscn"):
		kind = "core"
	elif identity.ends_with("pizza box.glb"):
		kind = "nest"
	elif identity.ends_with("fork.tscn"):
		kind = "shuttle"
	elif identity.ends_with("cupcake.tscn") or String(node.name) == "CakeVisual":
		kind = "knot"
	if kind.is_empty():
		return
	var ancestor := node.get_parent()
	while ancestor != null:
		if ancestor.has_meta("abstract_visual"):
			return
		ancestor = ancestor.get_parent()
	node.set_meta("abstract_visual", true)
	_hide_original(node)
	var art := Node3D.new()
	art.name = "AbstractSculpture"
	art.set_script(preload("res://theme_b/runtime/art/line_architecture/abstract_prop.gd"))
	art.set("kind", kind)
	node.add_child(art)

func _fluorescent(mesh_node: MeshInstance3D) -> void:
	if not is_instance_valid(mesh_node) or mesh_node.mesh == null or mesh_node.has_meta("fluorescent"):
		return
	var cursor: Node = mesh_node
	var owner_node: Node = mesh_node
	while owner_node != null:
		if owner_node.name == "AbstractSculpture":
			return
		owner_node = owner_node.get_parent()
	var eligible := false
	var pizza_slice := false
	var pizza_box := false
	var cake := false
	if mesh_node.name == "BlackCore":
		var vortex := ShaderMaterial.new()
		vortex.shader = preload("res://theme_b/runtime/art/line_architecture/portal_vortex.gdshader")
		mesh_node.material_override = vortex
		return
	while cursor != null:
		var identity := (String(cursor.name) + cursor.scene_file_path).to_lower()
		pizza_slice = pizza_slice or "pizza slice" in identity or "pizza_slice" in identity
		pizza_box = pizza_box or "pizza box" in identity
		cake = cake or "cake" in identity
		if "player" in identity or "tools" in identity or "tool_" in identity or "final_key" in identity or "pizza" in identity:
			eligible = true
		cursor = cursor.get_parent()
	if not eligible:
		return
	mesh_node.set_meta("fluorescent", true)
	for i in range(mesh_node.mesh.get_surface_count()):
		var source := mesh_node.get_active_material(i)
		if source is StandardMaterial3D:
			if pizza_box:
				var shaded := ShaderMaterial.new()
				shaded.shader = preload("res://theme_b/runtime/art/line_architecture/box_shading.gdshader")
				shaded.set_shader_parameter("base_color", source.albedo_color)
				if source.albedo_texture != null:
					shaded.set_shader_parameter("base_texture", source.albedo_texture)
				mesh_node.set_surface_override_material(i, shaded)
				continue
			var mat := source.duplicate() as StandardMaterial3D
			# Self-lit original colors/textures remain readable without any lights.
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_texture = mat.albedo_texture
			mat.emission_energy_multiplier = 1.08 if pizza_slice else (0.25 if cake else 0.45)
			mesh_node.set_surface_override_material(i, mat)

func _style(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	if node is Light3D:
		node.light_energy = 0.0
		node.visible = false
		return
	if node is WorldEnvironment and node.environment != null:
		node.environment.ambient_light_energy = 0.0
		node.environment.reflected_light_source = 2 # Disabled.
		return
	if node is CharacterBody3D and (node.is_in_group("player") or String(node.name).to_lower() == "player"):
		return
	if not (node is StaticBody3D or node is RigidBody3D):
		return
	var path := String(node.get_path()).to_lower()
	if "/walls/" in path or ("player" in path and not "playerblock" in path):
		return
	if not ("box" in path or "block" in path or "compoundpiece" in path):
		return
	if _contains_pizza(node):
		return
	var colliders: Array[CollisionShape3D] = []
	for child in node.get_children():
		if child is CollisionShape3D and child.shape is BoxShape3D and not child.has_meta("line_styled"):
			colliders.append(child)
	if colliders.is_empty():
		return
	_hide_original(node)
	var role := "static"
	if node is RigidBody3D:
		role = "movable"
	if "playerblock" in path:
		role = "temporary"
	if "deadly" in path or "compoundpiece_147" in path or "compoundpiece_92" in path:
		role = "danger"
	for collider in colliders:
		var visual := MeshInstance3D.new()
		visual.name = "LineArchitecture"
		visual.set_meta("line_visual", true)
		visual.mesh = _mesh(collider.shape.size, absi(String(node.get_path()).hash()) % 8)
		visual.material_override = _material(role, collider.shape.size)
		if role == "temporary":
			visual.material_override = visual.material_override.duplicate()
		visual.transform = collider.transform
		node.add_child(visual)
		_add_fireflies(visual, collider.shape.size, role == "temporary")
		collider.set_meta("line_styled", true)

func _add_fireflies(parent: Node3D, size: Vector3, temporary: bool = false) -> void:
	var flow := MultiMeshInstance3D.new()
	flow.set_script(preload("res://theme_b/runtime/art/line_architecture/surface_flow.gd"))
	flow.set("block_size", size)
	if temporary:
		flow.set("streams", 30)
		flow.set("speed", 0.8)
		flow.set("size_multiplier", 3.0)
	parent.add_child(flow)
func _contains_pizza(node: Node) -> bool:
	if "pizza" in String(node.name).to_lower() or "pizza" in node.scene_file_path.to_lower():
		return true
	for child in node.get_children():
		if _contains_pizza(child):
			return true
	return false

func _hide_original(node: Node) -> void:
	for child in node.get_children():
		if child.has_meta("line_visual") or child is PhysicsBody3D:
			continue
		if child is MeshInstance3D:
			child.visible = false
		_hide_original(child)

func _color(role: String) -> Color:
	if role == "movable":
		return Color("ffd69a")
	if role == "danger":
		return Color("ff657a")
	return Color("080808")

func _material(role: String, size: Vector3) -> ShaderMaterial:
	var key := role + str(size)
	if materials.has(key):
		return materials[key]
	var m := ShaderMaterial.new()
	m.shader = preload("res://theme_b/runtime/art/line_architecture/monochrome_surface.gdshader")
	m.set_shader_parameter("block_size", size)
	m.set_shader_parameter("forest_dark", Color("061c15"))
	m.set_shader_parameter("forest_mid", Color("104632"))
	m.set_shader_parameter("forest_teal", Color("27765d"))
	m.set_shader_parameter("layer_detail", 0.08)
	# Keep the darkest greens deep; fireflies carry the warm highlights.
	m.set_shader_parameter("surface_glow", 0.012)
	if role == "temporary":
		m.set_shader_parameter("forest_palette", false)
		m.set_shader_parameter("gray_range", Vector2(0.56, 0.94))
		m.set_shader_parameter("layer_detail", 0.16)
		m.set_shader_parameter("surface_glow", 0.12)
		m.set_shader_parameter("flow_strength", 0.0)
	materials[key] = m
	return m

func _append(surface: SurfaceTool, position: Vector3, size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	surface.append_from(box, 0, Transform3D(Basis.IDENTITY, position))

func _mesh(size: Vector3, variant: int = 0) -> ArrayMesh:
	var key := str(size) + ":" + str(variant)
	if mesh_cache.has(key):
		return mesh_cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 + variant * 113
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Square cross-section uses the old layer's shortest dimension.
	var thickness := minf(0.022, minf(size.x, minf(size.y, size.z)) * 0.12)
	# Independent positions and lengths avoid shared rows and cubic grid cells.
	var count := maxi(24, int(size.x*size.y*size.z*270))
	for i in range(count):
		var axis := rng.randi_range(0,2)
		var dimensions := Vector3.ONE * thickness
		dimensions[axis] = minf(size[axis], rng.randf_range(0.14,0.58))
		var center := Vector3.ZERO
		for component in range(3):
			var reach := maxf(0.0, (size[component]-dimensions[component])/2)
			center[component] = rng.randf_range(-reach,reach)
		_append(surface, center, dimensions)
	var result := surface.commit()
	mesh_cache[key] = result
	return result
