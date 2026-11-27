extends Control

@export var ring_color := Color(1.0, 0.79, 0.11, 0.95)
@export_range(30.0, 150.0, 1.0) var ring_radius := 76.0

var focus_point := Vector2.ZERO
var card_rect := Rect2()


func set_focus(point: Vector2, card: Rect2) -> void:
	focus_point = point
	card_rect = card
	queue_redraw()


func _draw() -> void:
	if card_rect.size == Vector2.ZERO:
		return
	var card_center := card_rect.get_center()
	var toward_card := (card_center - focus_point).normalized()
	var ring_edge := focus_point + toward_card * (ring_radius + 4.0)
	var line_end := Vector2(
		clampf(focus_point.x, card_rect.position.x, card_rect.end.x),
		clampf(focus_point.y, card_rect.position.y, card_rect.end.y)
	)
	draw_line(ring_edge, line_end, ring_color, 3.0, true)
	draw_arc(focus_point, ring_radius + 8.0, 0.0, TAU, 64, Color(ring_color, 0.35), 2.0, true)
	draw_arc(focus_point, ring_radius, 0.0, TAU, 64, ring_color, 4.0, true)
