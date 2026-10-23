extends Node2D

var reach: float = 120.0
var direction: float = 1.0
var remaining: float = 0.0
const DURATION: float = 0.19

func play(new_reach: float, new_direction: float) -> void:
	reach = new_reach
	direction = new_direction
	remaining = DURATION
	queue_redraw()

func _process(delta: float) -> void:
	if remaining > 0.0:
		remaining = maxf(0.0, remaining - delta)
		queue_redraw()

func _draw() -> void:
	if remaining <= 0.0:
		return
	var alpha: float = remaining / DURATION
	var start_angle: float = -1.1 if direction > 0.0 else PI - 1.1
	var end_angle: float = 1.1 if direction > 0.0 else PI + 1.1
	var origin: Vector2 = Vector2(0, -26)
	draw_arc(origin, reach, start_angle, end_angle, 24, Color(0.95, 0.22, 0.42, alpha * 0.8), 13.0, true)
	draw_arc(origin, reach - 12.0, start_angle, end_angle, 24, Color(1.0, 0.75, 0.78, alpha), 3.0, true)
