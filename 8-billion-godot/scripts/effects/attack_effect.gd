extends Node2D

var reach: float = 120.0
var direction: Vector2 = Vector2.RIGHT
var remaining: float = 0.0
const DURATION: float = 0.19
const HALF_ANGLE: float = 0.8

func play(new_reach: float, new_direction: Vector2) -> void:
	reach = new_reach
	direction = new_direction.normalized()
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
	var angle: float = direction.angle()
	var origin: Vector2 = Vector2(0.0, -28.0)
	draw_arc(origin, reach, angle - HALF_ANGLE, angle + HALF_ANGLE, 24, Color(0.95, 0.22, 0.42, alpha * 0.8), 13.0, true)
	draw_arc(origin, reach - 12.0, angle - HALF_ANGLE, angle + HALF_ANGLE, 24, Color(1.0, 0.75, 0.78, alpha), 3.0, true)
