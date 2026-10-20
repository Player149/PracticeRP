extends Control
## Mobile overlay: move with left thumb, swipe on right to look, tap DIG or JUMP.
signal jump_requested
signal dig_requested

var stick_center: Vector2 = Vector2.ZERO
var stick_axis: Vector2 = Vector2.ZERO
var stick_active: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _add_button("JUMP", -160.0, -138.0, 140.0, 105.0, false)
    _add_button("DIG", -160.0, -247.0, 140.0, 95.0, true)
    queue_redraw()

func _add_button(caption: String, left: float, top: float, width: float, height: float, is_dig: bool) -> void:
    var button: Button = Button.new()
    button.text = caption
    button.anchor_left = 1.0
    button.anchor_right = 1.0
    button.anchor_top = 1.0
    button.anchor_bottom = 1.0
    button.offset_left = left
    button.offset_right = left + width
    button.offset_top = top
    button.offset_bottom = top + height
    button.add_theme_font_size_override("font_size", 25)
    button.modulate = Color(0.83, 0.95, 1.0, 0.9)
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(button)
    if is_dig:
        button.pressed.connect(_emit_dig)
    else:
        button.pressed.connect(_emit_jump)

func _emit_dig() -> void:
    dig_requested.emit()

func _emit_jump() -> void:
    jump_requested.emit()

func set_stick(origin: Vector2, axis: Vector2, active: bool) -> void:
    stick_center = origin
    stick_axis = axis
    stick_active = active
    queue_redraw()

func _draw() -> void:
    var screen: Vector2 = get_viewport_rect().size
    var center: Vector2 = stick_center if stick_active else Vector2(screen.x * 0.15, screen.y * 0.80)
    draw_circle(center, 80.0, Color(0.13, 0.20, 0.28, 0.25))
    draw_arc(center, 80.0, 0.0, TAU, 48, Color(0.75, 0.92, 1.0, 0.62), 3.0)
    draw_circle(center + stick_axis * 52.0, 31.0, Color(0.60, 0.85, 1.0, 0.65))

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED:
        queue_redraw()
