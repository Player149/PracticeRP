extends Control
## Small mobile-only overlay. Gameplay touch tracking lives in player.gd.
signal jump_requested
signal run_changed(is_running: bool)

var stick_center: Vector2 = Vector2.ZERO
var stick_axis: Vector2 = Vector2.ZERO
var stick_active: bool = false

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    _add_button("JUMP", -160.0, -140.0, 140.0, 110.0, true)
    _add_button("RUN", -160.0, -245.0, 140.0, 85.0, false)
    queue_redraw()

func _add_button(caption: String, left: float, top: float, width: float, height: float, jump: bool) -> void:
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
    if jump:
        button.pressed.connect(_emit_jump)
    else:
        button.button_down.connect(_start_run)
        button.button_up.connect(_stop_run)

func _emit_jump() -> void:
    jump_requested.emit()

func _start_run() -> void:
    run_changed.emit(true)

func _stop_run() -> void:
    run_changed.emit(false)

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
