extends Node2D

# 8 BILLION - native Godot 4 gameplay prototype (procedural art).
const WORLD_WIDTH: float = 6000.0
const GRAVITY: float = 1450.0
const SPEED: float = 290.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var player: Dictionary = {}
var citizens: Array[Dictionary] = []
var projectiles: Array[Dictionary] = []
var buildings: Array[Dictionary] = []
var sparks: Array[Dictionary] = []
var inside_index: int = -1
var camera_x: float = 0.0
var ground_y: float = 560.0
var soul_count: int = 0
var kill_count: int = 0
var elapsed: float = 0.0
var spawn_timer: float = 0.0
var message: String = ""
var message_time: float = 0.0

func _ready() -> void:
	rng.randomize()
	reset_game()

func reset_game() -> void:
	var size: Vector2 = get_viewport_rect().size
	ground_y = size.y * 0.78
	player = {"x": 90.0, "y": ground_y - 52.0, "vx": 0.0, "vy": 0.0, "face": 1.0, "hp": 100.0, "cool": 0.0, "attack": 0.0, "dash": 0.0, "inv": 0.0}
	citizens.clear()
	projectiles.clear()
	buildings.clear()
	sparks.clear()
	inside_index = -1
	camera_x = 0.0
	soul_count = 0
	kill_count = 0
	elapsed = 0.0
	spawn_timer = 0.0
	for i in range(12):
		buildings.append({"x": 350.0 + float(i) * 450.0, "w": 235.0, "h": 195.0 + float(i % 3) * 30.0, "hp": 100.0, "dead": false})
	for i in range(140):
		var kind: int = 0
		var chance: float = rng.randf()
		if chance < 0.18:
			kind = 1
		elif chance < 0.25:
			kind = 2
		spawn_citizen(rng.randf_range(170.0, WORLD_WIDTH - 100.0), kind)
	say("8 BILLION - SOUL HARVEST")

func say(value: String) -> void:
	message = value
	message_time = 2.5

func spawn_citizen(x: float, kind: int) -> void:
	citizens.append({"x": x, "y": ground_y - 33.0, "vx": rng.randf_range(-55.0, 55.0), "vy": 0.0, "kind": kind, "hp": 1 if kind == 0 else 3, "fire": rng.randf_range(0.3, 2.5), "alive": true})

func emit_sparks(x: float, y: float, color: Color, count: int = 12) -> void:
	for i in range(count):
		sparks.append({"x": x, "y": y, "vx": rng.randf_range(-220.0, 220.0), "vy": rng.randf_range(-260.0, 40.0), "life": rng.randf_range(0.2, 0.8), "color": color})

func defeat_citizen(index: int) -> void:
	var p: Dictionary = citizens[index]
	if not p["alive"]:
		return
	p["alive"] = false
	citizens[index] = p
	kill_count += 1
	soul_count += 1
	emit_sparks(float(p["x"]), float(p["y"]), Color("#d74972"), 14)

func collapse(index: int) -> void:
	var b: Dictionary = buildings[index]
	if b["dead"]:
		return
	b["dead"] = true
	buildings[index] = b
	var harvested: int = rng.randi_range(30000, 180000)
	soul_count += harvested
	emit_sparks(float(b["x"]) + float(b["w"]) * 0.5, ground_y - 90.0, Color("#e2b28d"), 75)
	say("REGION HARVESTED: +" + str(harvested) + " SOULS")
	if inside_index == index:
		inside_index = -1
		player["x"] = float(b["x"]) + float(b["w"]) * 0.5
		player["y"] = ground_y - 52.0

func attack(heavy: bool) -> void:
	if float(player["cool"]) > 0.0:
		return
	player["cool"] = 0.65 if heavy else 0.25
	player["attack"] = 0.25
	var reach: float = 160.0 if heavy else 90.0
	var attack_center: float = float(player["x"]) + float(player["face"]) * reach * 0.5
	if inside_index >= 0:
		var b: Dictionary = buildings[inside_index]
		b["hp"] = maxf(0.0, float(b["hp"]) - (20.0 if heavy else 8.0))
		buildings[inside_index] = b
		emit_sparks(float(player["x"]) + 65.0, float(player["y"]) + 15.0, Color("#e6a270"))
		if float(b["hp"]) <= 0.0:
			collapse(inside_index)
	else:
		for i in range(citizens.size()):
			var p: Dictionary = citizens[i]
			if not p["alive"]:
				continue
			if absf(float(p["x"]) - attack_center) < reach * 0.5 + 14.0 and absf(float(p["y"]) - float(player["y"])) < 85.0:
				p["hp"] = int(p["hp"]) - (4 if heavy else 1)
				p["vx"] = float(p["vx"]) + float(player["face"]) * 220.0
				citizens[i] = p
				if int(p["hp"]) <= 0:
					defeat_citizen(i)
		for i in range(buildings.size()):
			var b: Dictionary = buildings[i]
			if b["dead"]:
				continue
			var tip: float = float(player["x"]) + float(player["face"]) * reach
			if tip >= float(b["x"]) and tip <= float(b["x"]) + float(b["w"]):
				b["hp"] = maxf(0.0, float(b["hp"]) - (15.0 if heavy else 5.0))
				buildings[i] = b
				emit_sparks(tip, ground_y - 80.0, Color("#c6a58c"))
				if float(b["hp"]) <= 0.0:
					collapse(i)

func interact() -> void:
	if inside_index >= 0:
		var b: Dictionary = buildings[inside_index]
		player["x"] = float(b["x"]) + float(b["w"]) * 0.5
		player["y"] = ground_y - 52.0
		inside_index = -1
		say("EXIT BUILDING")
		return
	for i in range(buildings.size()):
		var b: Dictionary = buildings[i]
		if not b["dead"] and absf(float(player["x"]) - (float(b["x"]) + float(b["w"]) * 0.5)) < float(b["w"]) * 0.5:
			inside_index = i
			player["x"] = 85.0
			player["y"] = ground_y - 52.0
			say("INSIDE: DESTROY THE CORE")
			return
	say("GET CLOSER TO A BUILDING")

func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	if not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_R:
			reset_game()
		KEY_E:
			interact()
		KEY_J:
			attack(false)
		KEY_K:
			attack(true)
		KEY_L:
			player["dash"] = 0.16

func _process(delta: float) -> void:
	var dt: float = minf(delta, 0.033)
	elapsed += dt
	message_time = maxf(0.0, message_time - dt)
	player["cool"] = maxf(0.0, float(player["cool"]) - dt)
	player["attack"] = maxf(0.0, float(player["attack"]) - dt)
	player["dash"] = maxf(0.0, float(player["dash"]) - dt)
	player["inv"] = maxf(0.0, float(player["inv"]) - dt)
	var move: float = float(int(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)))
	if move != 0.0:
		player["face"] = move
	player["vx"] = float(player["face"]) * 780.0 if float(player["dash"]) > 0.0 else move * SPEED
	if (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)) and float(player["y"]) >= ground_y - 52.0:
		player["vy"] = -590.0
	player["vy"] = float(player["vy"]) + GRAVITY * dt
	var bound: float = get_viewport_rect().size.x - 45.0 if inside_index >= 0 else WORLD_WIDTH - 40.0
	player["x"] = clampf(float(player["x"]) + float(player["vx"]) * dt, 0.0, bound)
	player["y"] = minf(ground_y - 52.0, float(player["y"]) + float(player["vy"]) * dt)
	if float(player["y"]) >= ground_y - 52.0:
		player["vy"] = 0.0
	if inside_index < 0:
		update_citizens(dt)
		update_projectiles(dt)
		spawn_timer += dt
		if spawn_timer > 0.7 and citizens.size() < 200:
			spawn_timer = 0.0
			spawn_citizen(clampf(float(player["x"]) + rng.randf_range(-650.0, 750.0), 0.0, WORLD_WIDTH), rng.randi_range(0, 2))
		camera_x = clampf(float(player["x"]) - get_viewport_rect().size.x * 0.38, 0.0, maxf(0.0, WORLD_WIDTH - get_viewport_rect().size.x))
	else:
		camera_x = 0.0
	for i in range(sparks.size() - 1, -1, -1):
		var s: Dictionary = sparks[i]
		s["x"] = float(s["x"]) + float(s["vx"]) * dt
		s["y"] = float(s["y"]) + float(s["vy"]) * dt
		s["vy"] = float(s["vy"]) + 320.0 * dt
		s["life"] = float(s["life"]) - dt
		if float(s["life"]) <= 0.0:
			sparks.remove_at(i)
		else:
			sparks[i] = s
	queue_redraw()

func update_citizens(dt: float) -> void:
	for i in range(citizens.size()):
		var p: Dictionary = citizens[i]
		if not p["alive"]:
			continue
		var distance: float = float(player["x"]) - float(p["x"])
		p["fire"] = float(p["fire"]) - dt
		if int(p["kind"]) == 0:
			if absf(distance) < 440.0:
				p["vx"] = float(p["vx"]) - signf(distance) * 520.0 * dt
			p["vx"] = clampf(float(p["vx"]) * 0.985, -210.0, 210.0)
		else:
			var target: float = 0.0
			if absf(distance) < 170.0:
				target = -signf(distance) * 110.0
			elif absf(distance) > 360.0:
				target = signf(distance) * 110.0
			p["vx"] = lerpf(float(p["vx"]), target, minf(1.0, dt * 2.0))
			if absf(distance) < 580.0 and float(p["fire"]) <= 0.0:
				var origin: Vector2 = Vector2(float(p["x"]), float(p["y"]) + 12.0)
				var toward: Vector2 = (Vector2(float(player["x"]), float(player["y"]) + 20.0) - origin).normalized()
				var grenade: bool = int(p["kind"]) == 2
				projectiles.append({"x": origin.x, "y": origin.y, "vx": toward.x * 490.0, "vy": -370.0 if grenade else toward.y * 490.0, "bomb": grenade, "life": 2.2})
				p["fire"] = rng.randf_range(2.8, 4.3) if grenade else rng.randf_range(0.9, 2.2)
		p["x"] = clampf(float(p["x"]) + float(p["vx"]) * dt, 0.0, WORLD_WIDTH)
		citizens[i] = p

func update_projectiles(dt: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var p: Dictionary = projectiles[i]
		p["x"] = float(p["x"]) + float(p["vx"]) * dt
		p["y"] = float(p["y"]) + float(p["vy"]) * dt
		p["life"] = float(p["life"]) - dt
		if p["bomb"]:
			p["vy"] = float(p["vy"]) + 900.0 * dt
		var impact: bool = (p["bomb"] and float(p["y"]) >= ground_y - 5.0)
		var near: bool = Vector2(float(p["x"]), float(p["y"])).distance_to(Vector2(float(player["x"]), float(player["y"]) + 20.0)) < 24.0
		if impact or near:
			if float(player["inv"]) <= 0.0 and float(player["dash"]) <= 0.0:
				if near or Vector2(float(p["x"]), float(p["y"])).distance_to(Vector2(float(player["x"]), float(player["y"]) + 20.0)) < 95.0:
					player["hp"] = float(player["hp"]) - (17.0 if p["bomb"] else 5.0)
					player["inv"] = 0.6
			if p["bomb"]:
				emit_sparks(float(p["x"]), float(p["y"]), Color("#ffab59"), 28)
			p["life"] = 0.0
		if float(p["life"]) <= 0.0:
			projectiles.remove_at(i)
		else:
			projectiles[i] = p
	if float(player["hp"]) <= 0.0:
		reset_game()

func block(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _draw() -> void:
	var viewport: Vector2 = get_viewport_rect().size
	block(0, 0, viewport.x, viewport.y, Color("#171a2b"))
	block(0, ground_y, viewport.x, viewport.y - ground_y, Color("#292a36"))
	if inside_index < 0:
		for i in range(60):
			var bx: float = float(i) * 125.0 - camera_x * 0.2
			block(bx, ground_y - 120.0 - float(i * 37 % 110), 110.0, 260.0, Color("#303344"))
		for b in buildings:
			var x: float = float(b["x"]) - camera_x
			if x > viewport.x or x + float(b["w"]) < 0.0:
				continue
			if b["dead"]:
				block(x, ground_y - 26.0, float(b["w"]), 26.0, Color("#67535d"))
				continue
			block(x, ground_y - float(b["h"]), float(b["w"]), float(b["h"]), Color("#555564"))
			for row in range(3):
				for col in range(4):
					block(x + 22.0 + float(col) * 49.0, ground_y - float(b["h"]) + 30.0 + float(row) * 49.0, 26.0, 31.0, Color("#d4a17d"))
			block(x + float(b["w"]) * 0.5 - 18.0, ground_y - 45.0, 36.0, 45.0, Color("#202330"))
			block(x, ground_y - float(b["h"]) - 11.0, float(b["w"]) * float(b["hp"]) / 100.0, 5.0, Color("#ee6b78"))
		for p in citizens:
			if not p["alive"]:
				continue
			var x: float = float(p["x"]) - camera_x
			if x < -30.0 or x > viewport.x + 30.0:
				continue
			block(x, float(p["y"]), 13.0, 10.0, Color("#d1b7a7"))
			block(x - 2.0, float(p["y"]) + 10.0, 17.0, 20.0, Color("#a6a2b2") if int(p["kind"]) == 0 else Color("#879b83"))
			block(x, float(p["y"]) + 30.0, 4.0, 5.0, Color("#272532"))
			block(x + 9.0, float(p["y"]) + 30.0, 4.0, 5.0, Color("#272532"))
			if int(p["kind"]) != 0:
				block(x + 12.0, float(p["y"]) + 16.0, 17.0, 4.0, Color("#151923"))
		for p in projectiles:
			block(float(p["x"]) - camera_x, float(p["y"]), 8.0 if p["bomb"] else 5.0, 5.0, Color("#ffaa57") if p["bomb"] else Color("#ffe5a2"))
	else:
		block(35.0, ground_y - 280.0, viewport.x - 70.0, 280.0, Color("#4b424f"))
		block(viewport.x * 0.62, ground_y - 205.0, 135.0, 205.0, Color("#75505d"))
		for i in range(4):
			block(viewport.x * 0.62 + 19.0 + float(i) * 28.0, ground_y - 170.0, 14.0, 120.0, Color("#d96e60"))
		block(viewport.x * 0.62, ground_y - 221.0, 135.0 * float(buildings[inside_index]["hp"]) / 100.0, 7.0, Color("#ff7677"))
	for s in sparks:
		block(float(s["x"]) - (0.0 if inside_index >= 0 else camera_x), float(s["y"]), 5.0, 5.0, s["color"])
	var px: float = float(player["x"]) - (0.0 if inside_index >= 0 else camera_x)
	var py: float = float(player["y"])
	if float(player["inv"]) <= 0.0 or int(elapsed * 20.0) % 2 == 0:
		block(px + 4.0, py, 22.0, 32.0, Color("#090911"))
		block(px + 8.0, py - 10.0, 14.0, 14.0, Color("#090911"))
		block(px + 7.0, py + 30.0, 5.0, 22.0, Color("#090911"))
		block(px + 21.0, py + 30.0, 5.0, 22.0, Color("#090911"))
		block(px + 9.0, py - 3.0, 5.0, 3.0, Color("#ff5a88"))
		if float(player["attack"]) > 0.0:
			draw_arc(Vector2(px + 15.0, py + 20.0), 78.0, -1.1 if float(player["face"]) > 0 else 2.0, 1.0 if float(player["face"]) > 0 else 4.2, 28, Color("#ff5c8d"), 15.0)
	block(12.0, 67.0, 204.0, 13.0, Color("#313447"))
	block(14.0, 69.0, 200.0 * clampf(float(player["hp"]) / 100.0, 0.0, 1.0), 9.0, Color("#d94672"))
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(14.0, 25.0), "8 BILLION  |  GODOT PROTOTYPE", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)
	draw_string(font, Vector2(14.0, 50.0), "Defeated: %d   Souls: %d   Buildings: %d/12" % [kill_count, soul_count, count_destroyed()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
	draw_string(font, Vector2(14.0, 103.0), "A/D move  W jump  J attack  K heavy  L dash  E enter/exit  R restart", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#d5d6e3"))
	if message_time > 0.0:
		draw_string(font, Vector2(viewport.x * 0.3, viewport.y * 0.25), message, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#ffe1c4"))

func count_destroyed() -> int:
	var total: int = 0
	for b in buildings:
		if b["dead"]:
			total += 1
	return total
