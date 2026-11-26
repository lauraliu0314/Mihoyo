extends Node3D

var kind := "core"
var elapsed := 0.0
var released := false
var seal: Node3D
var sculpture: Node3D
var seal_material: StandardMaterial3D
var locked_core := false

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.4
	return m

func ring(parent: Node3D, radius: float, at: Vector3, tilt: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius-0.012
	torus.outer_radius = radius+0.012
	torus.rings = 36
	torus.ring_segments = 8
	mesh.mesh = torus
	mesh.material_override = mat
	mesh.position = at
	mesh.rotation = tilt
	parent.add_child(mesh)

func rod(at: Vector3, size: Vector3, tilt: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	mesh.rotation = tilt
	sculpture.add_child(mesh)

func _ready() -> void:
	set_meta("abstract_visual", true)
	sculpture = Node3D.new()
	add_child(sculpture)
	var gold := material(Color("ffd37d"))
	var silver := material(Color("bcb6ef"))
	if kind == "core":
		# Tangent shards loosely surround a volume; no closed rings or shell.
		var rng := RandomNumberGenerator.new()
		rng.seed = 4271
		for i in range(22):
			var y := 1.0-2.0*(float(i)+0.5)/22.0
			var angle := i*2.39996+rng.randf_range(-0.16,0.16)
			var radial := sqrt(1.0-y*y)
			var normal := Vector3(cos(angle)*radial,y,sin(angle)*radial).normalized()
			var distance := rng.randf_range(0.27,0.34)
			var tangent := normal.cross(Vector3.UP).normalized()
			var frame := Basis(tangent,normal,tangent.cross(normal).normalized())
			rod(normal*distance,Vector3(rng.randf_range(0.17,0.25),0.013,rng.randf_range(0.09,0.15)),Vector3.ZERO,gold)
			var shard := sculpture.get_child(sculpture.get_child_count()-1) as MeshInstance3D
			shard.basis = frame.rotated(normal,rng.randf_range(-0.5,0.5))
			shard.set_meta("floating_shard",true)
			shard.set_meta("rest_position",shard.position)
			shard.set_meta("rest_basis",shard.basis)
			shard.set_meta("phase",rng.randf_range(0.0,TAU))
		var orb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.1
		sphere.height = 0.2
		orb.mesh = sphere
		orb.material_override = gold
		sculpture.add_child(orb)
	elif kind == "nest":
		for i in range(3):
			ring(sculpture,0.38-i*0.055,Vector3(0,-0.23+i*0.07,0),Vector3(0,0,i*0.08),gold)
		for i in range(8):
			var a := i*TAU/8
			rod(Vector3(cos(a)*0.34,-0.08,sin(a)*0.34),Vector3(0.018,0.22,0.018),Vector3(sin(a)*0.25,0,-cos(a)*0.25),gold)
	elif kind == "shuttle":
		for petal in range(3):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var angle := petal*TAU/3
			for segment in range(24):
				var points: Array[Vector3] = []
				for corner in [Vector2(segment/24.0,-1),Vector2((segment+1)/24.0,-1),Vector2((segment+1)/24.0,1),Vector2(segment/24.0,1)]:
					var t: float = corner.x
					var r := sin(t*PI)*0.23
					var width: float = sin(t*PI)*0.1*corner.y
					points.append(Vector3(cos(angle)*r-sin(angle)*width,lerpf(-0.4,0.32,t),sin(angle)*r+cos(angle)*width))
				for index in [0,1,2,0,2,3]:
					surface.add_vertex(points[index])
			surface.generate_normals()
			var petal_mesh := MeshInstance3D.new()
			petal_mesh.mesh = surface.commit()
			var petal_material := material(Color("d5cbff"))
			petal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			petal_mesh.material_override = petal_material
			sculpture.add_child(petal_mesh)
		var heart := MeshInstance3D.new()
		var heart_shape := SphereMesh.new()
		heart_shape.radius = 0.065
		heart_shape.height = 0.13
		heart.mesh = heart_shape
		heart.scale = Vector3(1,3.4,1)
		heart.material_override = silver
		sculpture.add_child(heart)
	else:
		for i in range(6):
			ring(sculpture,0.28+sin(i)*0.055,Vector3(0,(i-2.5)*0.045,0),Vector3(i*0.35,0,i*0.5),silver)
	seal = Node3D.new()
	add_child(seal)
	seal_material = material(Color("ff435d"))
	seal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in range(3):
		if kind != "core":
			ring(seal,0.44,Vector3.ZERO,Vector3(i*PI/3,0,i*PI/3),seal_material)
	# The movable core is an input, not a locked device.
	seal.visible = kind != "core"
func _is_released() -> bool:
	var node := get_parent()
	while node != null:
		for property in node.get_property_list():
			var key := String(property.name)
			if key in ["is_open", "_unlocked", "_collected", "gravity_enabled", "adsorbed"] and node.get(key) == true:
				return true
		node = node.get_parent()
	return false

func _process(delta: float) -> void:
	elapsed += delta
	var host := get_parent()
	locked_core = false
	while host != null:
		if host.has_meta("locked_in_e1"):
			locked_core = true
			break
		host = host.get_parent()
	sculpture.position.y = 0.0 if locked_core else sin(elapsed*0.8)*0.025
	if not locked_core:
		sculpture.rotation.y += delta*(0.16 if kind == "core" else 0.06)
		if kind == "core":
			for shard in sculpture.get_children():
				if not shard.has_meta("floating_shard"):
					continue
				var rest: Vector3 = shard.get_meta("rest_position")
				var rest_basis: Basis = shard.get_meta("rest_basis")
				var phase: float = shard.get_meta("phase")
				shard.position = rest + rest.normalized()*sin(elapsed*0.65+phase)*0.012
				shard.basis = rest_basis.rotated(rest_basis.x,sin(elapsed*0.45+phase)*0.06)
	seal.rotation.y -= delta*0.24
	seal.rotation.z = sin(elapsed*0.5)*0.15
	var state := _is_released()
	# Removal is permanent for this instance. Absorption turns gravity off;
	# that must never re-arm the seal. Hide geometry, not just material alpha.
	if kind == "core" or released or state:
		seal.hide()
	if state and not released:
		released = true
		var tween := create_tween().set_parallel(true)
		if kind == "knot":
			for piece in sculpture.get_children():
				var direction := Vector3(sin(piece.get_index()*2.4),0.5,cos(piece.get_index()*2.4))
				tween.tween_property(piece,"position",piece.position+direction*0.35,0.6)
				tween.tween_property(piece,"scale",Vector3.ONE*0.01,0.65)
		else:
			tween.kill()
