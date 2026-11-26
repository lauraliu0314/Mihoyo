extends MultiMeshInstance3D

var block_size := Vector3.ONE
var elapsed := 0.0
var streams := 6
var speed := 0.16
var size_multiplier := 1.0
var burn_progress := 0.0
var visual_fade := 1.0
const TRAIL := 6

func _ready() -> void:
	name = "SurfaceFlow"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(0.11,0.11) * size_multiplier
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://theme_b/runtime/art/line_architecture/firefly.gdshader")
	quad.material = mat
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = quad
	multimesh.instance_count = streams * TRAIL
	var margin := 0.2 * size_multiplier
	custom_aabb = AABB(-block_size/2-Vector3.ONE*margin, block_size+Vector3.ONE*margin*2.0)
	elapsed = float(absi(String(get_path()).hash()) % 1000)
	_process(0.0)

func _process(delta: float) -> void:
	elapsed += delta
	var fuel := 1.0 - burn_progress
	if multimesh != null:
		(multimesh.mesh as QuadMesh).size = Vector2.ONE * 0.11 * size_multiplier * lerpf(0.25, 1.0, fuel) * maxf(visual_fade, 0.001)
	for stream in range(streams):
		var axis := stream % 3
		var u := (axis+1)%3
		var v := (axis+2)%3
		for tail in range(TRAIL):
			# Slow closed paths lie on each face; older samples form a fading tail.
			var t := (elapsed - tail*0.28)*speed + stream*1.7
			var p := Vector3.ZERO
			p[axis] = (block_size[axis]/2+0.018)*(1.0 if stream%2 == 0 else -1.0)
			p[u] = sin(t)*block_size[u]*0.43
			p[v] = cos(t*1.31+stream)*block_size[v]*0.43
			var index := stream*TRAIL+tail
			multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY,p))
			multimesh.set_instance_custom_data(index, Color(pow(1.0-float(tail)/TRAIL,2.0)*lerpf(0.15,1.0,fuel)*visual_fade,0,0,1))
