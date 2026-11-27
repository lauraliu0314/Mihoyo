extends Control

## 通关提示卡里的小机制图标；全部程序化绘制，不依赖贴图。

enum Kind { ORB, FLIP, TOWER, EXIT, WARN }

@export var kind: Kind = Kind.ORB
@export var accent := Color(1.0, 0.0, 0.41)


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(40, 40)
	size = custom_minimum_size
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var s := size
	match kind:
		Kind.ORB:
			_draw_orb(s)
		Kind.FLIP:
			_draw_flip(s)
		Kind.TOWER:
			_draw_tower(s)
		Kind.EXIT:
			_draw_exit(s)
		Kind.WARN:
			_draw_warn(s)


func _draw_orb(s: Vector2) -> void:
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.30
	draw_circle(c, r * 1.55, Color(accent.r, accent.g, accent.b, 0.16))
	draw_circle(c, r * 1.22, Color(accent.r, accent.g, accent.b, 0.26))
	draw_circle(c, r, accent)
	draw_circle(c + Vector2(-r * 0.30, -r * 0.34), r * 0.30, Color(1, 1, 1, 0.72))
	draw_arc(c, r, 0.3, 2.2, 18, Color(1, 1, 1, 0.58), 1.6, true)


func _draw_flip(s: Vector2) -> void:
	var inset := 9.0
	var box := Rect2(Vector2(inset, inset), s - Vector2(inset * 2.0, inset * 2.0))
	draw_rect(box, Color(accent.r, accent.g, accent.b, 0.16), true)
	draw_rect(box, accent, false, 3.0, true)
	var arrow_color := accent.darkened(0.38)
	var tick := 6.0
	for corner in [box.position, Vector2(box.end.x, box.position.y), Vector2(box.position.x, box.end.y), box.end]:
		draw_line(corner, corner + Vector2(tick if corner.x < s.x * 0.5 else -tick, 0), arrow_color, 2.0)
	var c := s * 0.5
	draw_arc(c, 10.0, PI * 0.15, PI * 1.40, 18, arrow_color, 2.4, true)
	var tip := c + Vector2(-8.5, -7.5)
	draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(6.5, 1.0), tip + Vector2(-0.5, 7.0)]), arrow_color)


func _draw_tower(s: Vector2) -> void:
	var base_y := s.y - 7.0
	var widths := [18.0, 16.0, 14.0, 12.0]
	var heights := [7.0, 10.0, 13.0, 16.0]
	var colors := [
		Color(1.0, 0.0, 0.41),
		Color(0.13, 0.83, 0.93),
		Color(0.49, 0.23, 0.93),
		Color(1.0, 0.72, 0.18),
	]
	for i in range(4):
		var w: float = widths[i]
		var h: float = heights[i]
		var x := s.x * 0.5 - w * 0.5
		var y := base_y - h
		draw_rect(Rect2(x, y, w, h), colors[i], true)
		draw_rect(Rect2(x, y, w, h), Color(1, 1, 1, 0.40), false, 1.0, true)
		base_y = y
	# 向上箭头
	var ax := s.x - 7.0
	draw_line(Vector2(ax, s.y - 6.0), Vector2(ax, 8.0), accent, 2.2, true)
	draw_colored_polygon(PackedVector2Array([Vector2(ax, 4.0), Vector2(ax - 4.0, 10.0), Vector2(ax + 4.0, 10.0)]), accent)


func _draw_exit(s: Vector2) -> void:
	var c := s * 0.5
	var r := minf(s.x, s.y) * 0.31
	draw_circle(c, r * 1.28, Color(accent.r, accent.g, accent.b, 0.18))
	draw_circle(c, r, Color(0.13, 0.13, 0.15))
	draw_circle(c, r * 0.72, Color(0.82, 0.88, 0.94))
	draw_circle(c, r * 0.42, Color(0.97, 0.99, 1.0))
	draw_arc(c, r, -2.4, -0.4, 18, Color(1, 1, 1, 0.75), 2.0, true)


func _draw_warn(s: Vector2) -> void:
	var tri := PackedVector2Array([
		Vector2(s.x * 0.5, 5.0),
		Vector2(s.x - 5.0, s.y - 6.0),
		Vector2(5.0, s.y - 6.0),
	])
	draw_colored_polygon(tri, accent)
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.45, 0.05, 0.08), 1.6, true)
	draw_line(Vector2(s.x * 0.5, s.y * 0.38), Vector2(s.x * 0.5, s.y * 0.66), Color(1, 1, 1, 0.95), 2.4, true)
	draw_circle(Vector2(s.x * 0.5, s.y * 0.78), 1.6, Color(1, 1, 1, 0.95))
