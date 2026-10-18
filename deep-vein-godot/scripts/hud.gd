extends CanvasLayer
## Readable first-person HUD with mobile touch buttons.
signal scan_requested
signal sell_requested
signal upgrade_requested
signal new_mine_requested
signal jump_requested

const StickScene = preload("res://scripts/joystick.gd")
var joystick: Control
var mining: bool = false
var information: Label
var inventory: Label
var instructions: Label
var notice: Label
var notice_timer: float = 0.0
var scan_text: String = ""
var scan_timer: float = 0.0

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.name = "HUD"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top_panel := PanelContainer.new()
	top_panel.anchor_right = 1.0
	top_panel.offset_left = 12
	top_panel.offset_top = 12
	top_panel.offset_right = -12
	top_panel.offset_bottom = 122
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_panel)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_child(rows)
	information = Label.new()
	information.add_theme_font_size_override("font_size", 23)
	information.text = "DEEP VEIN  |  Scanning the cave..."
	rows.add_child(information)
	inventory = Label.new()
	inventory.add_theme_font_size_override("font_size", 18)
	inventory.text = "Ore cargo: 0"
	rows.add_child(inventory)

	notice = Label.new()
	notice.anchor_left = 0.18
	notice.anchor_right = 0.82
	notice.anchor_top = 0.25
	notice.anchor_bottom = 0.42
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.add_theme_font_size_override("font_size", 29)
	notice.add_theme_color_override("font_color", Color("ffe48a"))
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notice)

	var crosshair := Label.new()
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -12
	crosshair.offset_right = 12
	crosshair.offset_top = -18
	crosshair.offset_bottom = 18
	crosshair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	crosshair.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 27)
	crosshair.add_theme_color_override("font_color", Color(0.9, 0.98, 1.0, 0.8))
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair)

	instructions = Label.new()
	instructions.anchor_top = 1.0
	instructions.anchor_bottom = 1.0
	instructions.anchor_left = 0.23
	instructions.anchor_right = 0.77
	instructions.offset_top = -45
	instructions.offset_bottom = -10
	instructions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instructions.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	instructions.text = "WASD move  •  Mouse aim  •  Hold click mine  •  F scan  •  E sell  •  U upgrade  •  N new mine"
	instructions.add_theme_font_size_override("font_size", 16)
	instructions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(instructions)

	joystick = StickScene.new()
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 12
	joystick.offset_top = -220
	joystick.offset_right = 212
	joystick.offset_bottom = -20
	root.add_child(joystick)

	_make_button(root, "DIG", -125, -125, 115, 94, func(): mining = true, func(): mining = false)
	_make_button(root, "JUMP", -256, -112, 115, 80, func(): jump_requested.emit())
	_make_button(root, "SCAN", -125, -225, 115, 80, func(): scan_requested.emit())
	_make_button(root, "SELL", -256, -205, 115, 75, func(): sell_requested.emit())
	_make_button(root, "UP", -125, -307, 115, 73, func(): upgrade_requested.emit())
	_make_button(root, "NEW", -256, -286, 115, 68, func(): new_mine_requested.emit())

	var on_phone := OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	joystick.visible = on_phone
	for child in root.get_children():
		if child is Button:
			child.visible = on_phone
	instructions.visible = not on_phone

func _make_button(root: Control, caption: String, x: float, y: float, w: float, h: float, press: Callable, release: Callable = Callable()) -> void:
	var btn := Button.new()
	btn.text = caption
	btn.anchor_left = 1.0
	btn.anchor_right = 1.0
	btn.anchor_top = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = x
	btn.offset_right = x + w
	btn.offset_top = y
	btn.offset_bottom = y + h
	btn.add_theme_font_size_override("font_size", 22)
	btn.modulate = Color(0.84, 0.93, 1.0, 0.85)
	root.add_child(btn)
	btn.button_down.connect(press)
	if release.is_valid():
		btn.button_up.connect(release)

func show_notice(message: String, duration: float = 2.6) -> void:
	notice.text = message
	notice_timer = duration

func show_scan(message: String) -> void:
	scan_text = message
	scan_timer = 6.0
	show_notice(message, 3.0)

func set_hud(wallet: int, level: int, cost: int, total_digs: int, cargo: Dictionary) -> void:
	information.text = "DEEP VEIN     $%d     Drill Lv.%d (next $%d)     Rock removed: %d" % [wallet, level, cost, total_digs]
	var parts: Array[String] = []
	for key in cargo.keys():
		if int(cargo[key]) > 0:
			parts.append("%s x%d" % [str(key), int(cargo[key])])
	inventory.text = "CARGO: " + ("  |  ".join(parts) if not parts.is_empty() else "empty")

func _process(delta: float) -> void:
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			notice.text = ""
	if scan_timer > 0.0:
		scan_timer -= delta
