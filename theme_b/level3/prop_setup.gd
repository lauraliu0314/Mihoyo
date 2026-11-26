extends "res://theme_b/runtime.gd"

func _ready() -> void:
	_setup.call_deferred()

func _setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var cube := get_node("Node3D") as Node3D
	var receiver := cube.get_node("Tool_B_D_G/G_Tool")
	var nest := receiver.get_node("Pizza Box") as Node3D
	receiver.detection_offset = nest.position
	receiver.get_node("DetectionArea").position = nest.position
	receiver.enable_idle_float = false
	var snap := receiver.get_node("PizzaSnapPoint") as Node3D
	snap.position = nest.position
	_align(cube, cube)

func _align(node: Node, cube: Node3D) -> void:
	if node.name == "AbstractSculpture":
		var art := node as Node3D
		var p := cube.to_local(art.global_position)
		var distances := [absf(p.x+3),absf(p.x-3),absf(p.y),absf(p.y-6),absf(p.z+3),absf(p.z-3)]
		var normals := [Vector3.RIGHT,Vector3.LEFT,Vector3.UP,Vector3.DOWN,Vector3.BACK,Vector3.FORWARD]
		var nearest := 0
		for i in range(1,6):
			if distances[i] < distances[nearest]:
				nearest = i
		var normal: Vector3 = normals[nearest]
		var rotation_basis := Basis(Quaternion(Vector3.UP, normal))
		art.global_basis = cube.global_basis.orthonormalized() * rotation_basis
	for child in node.get_children():
		_align(child,cube)
