extends Node2D

# Elastic shadow limb + broad crescent slash, sharing the combat hit radius.
@export var duration: float = 0.24
@export var half_angle: float = 0.8
@export var arm_width: float = 18.0
var reach: float = 120.0
var direction: Vector2 = Vector2.RIGHT
var elapsed: float = 1.0

func play(new_reach: float, new_direction: Vector2) -> void:
	reach = new_reach
	direction = new_direction.normalized()
	elapsed = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	if elapsed < duration:
		elapsed = minf(duration, elapsed + delta)
		queue_redraw()

func _draw() -> void:
	if elapsed >= duration:
		return
	var t: float = elapsed / duration
	var extension: float = sin(t * PI) # extends and retracts
	var fade: float = pow(1.0 - t, 0.65)
	var origin := Vector2(0.0, -27.0)
	var tip: Vector2 = origin + direction * reach * extension
	var normal := Vector2(-direction.y, direction.x)
	# Thick tapered organic limb and claw.
	var elbow: Vector2 = origin + direction * (reach * extension * 0.5) + normal * (12.0 * sin(t * TAU))
	var points := PackedVector2Array([
		origin + normal * arm_width,
		elbow + normal * (arm_width * 0.65),
		tip + normal * 8.0,
		tip + direction * 14.0,
		tip - normal * 8.0,
		elbow - normal * (arm_width * 0.65),
		origin - normal * arm_width
	])
	draw_colored_polygon(points, Color(0.045, 0.04, 0.065, fade))
	draw_circle(tip, 10.0 * extension, Color(0.07, 0.05, 0.09, fade))
	# Slash follows the same arc and maximum radius as the actual hit test.
	var center: float = direction.angle()
	var sweep: float = lerpf(-half_angle, half_angle, minf(t * 1.6, 1.0))
	var arc_start: float = center - half_angle
	var arc_end: float = center + sweep
	if arc_end > arc_start:
		draw_arc(origin, reach, arc_start, arc_end, 30, Color(0.91, 0.13, 0.34, fade * 0.7), 18.0, true)
		draw_arc(origin, reach - 8.0, arc_start, arc_end, 30, Color(1.0, 0.71, 0.76, fade), 4.0, true)
		draw_arc(origin, reach + 9.0, arc_start, arc_end, 30, Color(0.4, 0.03, 0.12, fade * 0.55), 5.0, true)
