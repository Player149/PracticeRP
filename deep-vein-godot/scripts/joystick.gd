extends Control
## Multitouch-safe left joystick; the right half of the screen is for looking.
var finger: int = -1
var value := Vector2.ZERO
var center := Vector2.ZERO
const RADIUS: float = 63.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	center = size / 2.0

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and finger == -1 and get_global_rect().has_point(event.position):
			finger = event.index
			_update_joystick(event.position)
		elif not event.pressed and event.index == finger:
			finger = -1
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == finger:
		_update_joystick(event.position)

func _update_joystick(point: Vector2) -> void:
	value = ((point - global_position) - center) / RADIUS
	value = value.limit_length(1.0)
	queue_redraw()

func _draw() -> void:
	center = size / 2.0
	draw_circle(center, RADIUS + 15.0, Color(0.2, 0.32, 0.4, 0.23))
	draw_arc(center, RADIUS + 15.0, 0.0, TAU, 56, Color(0.52, 0.82, 0.9, 0.55), 2.0)
	draw_circle(center + value * RADIUS, 28.0, Color(0.50, 0.87, 0.97, 0.55))
