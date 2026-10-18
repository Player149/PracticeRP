extends Node3D
## Main prototype loop: uncover a seamless 3D cave, harvest deposits, upgrade.
const TerrainScript = preload("res://scripts/terrain.gd")
const PlayerScript = preload("res://scripts/player.gd")
const OreScript = preload("res://scripts/ore.gd")
const HudScript = preload("res://scripts/hud.gd")

var terrain
var player
var hud
var ore_holder: Node3D
var rng := RandomNumberGenerator.new()
var credits: int = 0
var upgrade_level: int = 1
var rock_count: int = 0
var collected: Dictionary = {}
var mine_cooldown: float = 0.0
var refresh_timer: float = 0.0
var deposits: Array[StaticBody3D] = []

func _ready() -> void:
	_create_environment()
	terrain = TerrainScript.new()
	terrain.name = "EditableCaveTerrain"
	add_child(terrain)
	ore_holder = Node3D.new()
	ore_holder.name = "MineralDeposits"
	add_child(ore_holder)
	player = PlayerScript.new()
	player.name = "Miner"
	add_child(player)
	hud = HudScript.new()
	add_child(hud)
	player.joystick = hud.joystick
	hud.scan_requested.connect(_scan)
	hud.sell_requested.connect(_sell)
	hud.upgrade_requested.connect(_upgrade)
	hud.new_mine_requested.connect(_new_expedition)
	hud.jump_requested.connect(func(): player.touch_jump = true)
	_new_expedition()
	hud.show_notice("Dig rock to reveal hidden veins. Explore natural caves!", 5.0)

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("09101a")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("74829b")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var spots = [
		[Vector3(0, -4.2, 0), Color("79bfff"), 2.0, 16.0],
		[Vector3(12.2, -4.8, -8.5), Color("5adcb7"), 1.9, 13.5],
		[Vector3(-12.2, -6.1, 11.5), Color("ab7efa"), 2.2, 13.5]
	]
	for item in spots:
		var glow := OmniLight3D.new()
		glow.position = item[0]
		glow.light_color = item[1]
		glow.light_energy = item[2]
		glow.omni_range = item[3]
		glow.shadow_enabled = false
		add_child(glow)

func _new_expedition() -> void:
	for child in ore_holder.get_children():
		child.queue_free()
	deposits.clear()
	collected.clear()
	rock_count = 0
	rng.randomize()
	terrain.new_mine(rng.randi_range(0, 2000000000))
	_generate_ores()
	player.position = Vector3(0.0, -7.35, 1.0)
	player.velocity = Vector3.ZERO
	player.rotation = Vector3.ZERO
	player.camera.rotation = Vector3.ZERO
	hud.show_notice("New mine! Exposed ore + secret deposits in the rock.", 4.0)
	_update_hud()

func _generate_ores() -> void:
	# Exposed crystals found while walking through the caves, and deposits
	# buried 1-3m in the rock for genuine prospecting/digging surprises.
	for i in range(240):
		var cave_idx: int = rng.randi_range(0, terrain.caves.size() - 1)
		var cave: Dictionary = terrain.caves[cave_idx]
		var center: Vector3 = cave["center"]
		var direction := Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-0.78, 0.78), rng.randf_range(-1.0, 1.0)).normalized()
		if direction.length_squared() < 0.05:
			continue
		var edge := _find_rock_surface(center, direction)
		if edge == Vector3.INF:
			continue
		var hidden := i >= 85
		var spawn_pos: Vector3 = edge + direction * (rng.randf_range(0.8, 2.5) if hidden else -0.18)
		var limits: Vector3 = TerrainScript.ORIGIN + Vector3(TerrainScript.COUNT.x, TerrainScript.COUNT.y, TerrainScript.COUNT.z) * TerrainScript.CHUNK
		if spawn_pos.x <= TerrainScript.ORIGIN.x + 1.0 or spawn_pos.x >= limits.x - 1.0:
			continue
		if spawn_pos.y <= TerrainScript.ORIGIN.y + 1.0 or spawn_pos.y >= limits.y - 1.0:
			continue
		if spawn_pos.z <= TerrainScript.ORIGIN.z + 1.0 or spawn_pos.z >= limits.z - 1.0:
			continue
		if hidden and terrain.base_density(spawn_pos) < 0.55:
			continue
		if not hidden and terrain.base_density(spawn_pos) > 0.3:
			continue
		if spawn_pos.distance_to(Vector3(0, -7.4, 1)) < 2.1:
			continue
		var too_close := false
		for other in deposits:
			if other.position.distance_squared_to(spawn_pos) < 1.3:
				too_close = true
				break
		if too_close:
			continue
		var kind := _random_rarity()
		var ore = OreScript.new()
		ore.name = "Ore_%s_%d" % [OreScript.LABELS[kind], i]
		ore.position = spawn_pos
		ore.setup(kind, -direction, rng.randf_range(0.75, 1.22))
		ore.mined.connect(_on_ore_mined)
		ore_holder.add_child(ore)
		deposits.append(ore)

func _find_rock_surface(start: Vector3, direction: Vector3) -> Vector3:
	var previous: float = terrain.base_density(start)
	for i in range(1, 58):
		var p: Vector3 = start + direction * (float(i) * 0.28)
		var next: float = terrain.base_density(p)
		if next > 0.10 and previous < 0.0:
			return p
		previous = next
	return Vector3.INF

func _random_rarity() -> int:
	var roll := rng.randf()
	if roll < 0.43: return 0
	if roll < 0.67: return 1
	if roll < 0.85: return 2
	if roll < 0.947: return 3
	if roll < 0.989: return 4
	return 5

func _process(delta: float) -> void:
	mine_cooldown -= delta
	refresh_timer -= delta
	var mouse_mining := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	if (mouse_mining or hud.mining) and mine_cooldown <= 0.0:
		mine_cooldown = maxf(0.11, 0.28 - float(upgrade_level) * 0.026)
		_try_mine()
	if refresh_timer <= 0.0:
		refresh_timer = 0.22
		_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F:
				_scan()
			KEY_E:
				_sell()
			KEY_U:
				_upgrade()
			KEY_N:
				_new_expedition()

func _try_mine() -> void:
	var eye: Vector3 = player.eye()
	var end: Vector3 = eye + player.sight() * (4.0 + float(upgrade_level) * 0.45)
	var query := PhysicsRayQueryParameters3D.create(eye, end, 3)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var target: Object = hit["collider"]
	if target.has_method("strike"):
		target.call("strike")
		return
	var pos: Vector3 = hit["position"]
	var norm: Vector3 = hit["normal"]
	var radius: float = 1.02 + 0.13 * float(upgrade_level - 1)
	if terrain.dig(pos - norm * 0.36, radius):
		rock_count += 1
		if rock_count % 7 == 0:
			credits += 1

func _on_ore_mined(kind: int, _value: int, _location: Vector3) -> void:
	var ore_name: String = OreScript.LABELS[kind]
	collected[ore_name] = int(collected.get(ore_name, 0)) + 1
	var exclamation := "RARE DISCOVERY! " if kind >= 4 else "Found "
	hud.show_notice(exclamation + ore_name + " ore", 2.2 if kind < 4 else 4.0)
	_update_hud()

func _scan() -> void:
	var nearest: StaticBody3D = null
	var shortest := 16.0
	for deposit in deposits:
		if not is_instance_valid(deposit) or deposit.is_queued_for_deletion():
			continue
		var dist: float = player.global_position.distance_to(deposit.global_position)
		if dist < shortest:
			shortest = dist
			nearest = deposit
	if nearest == null:
		hud.show_scan("Nothing detected within 16m. Keep exploring!")
		return
	var toward: Vector3 = nearest.global_position - player.global_position
	var local: Vector3 = player.global_basis.inverse() * toward
	var angle: float = rad_to_deg(atan2(local.x, -local.z))
	var direction_text := "Ahead"
	if angle > 35.0: direction_text = "Right"
	if angle < -35.0: direction_text = "Left"
	if absf(angle) > 135.0: direction_text = "Behind"
	var prefix := "Above" if toward.y > 3.0 else ("Below" if toward.y < -3.0 else direction_text)
	hud.show_scan("Scanner: %s ore, %.1fm, %s" % [OreScript.LABELS[int(nearest.get("type_id"))], shortest, prefix])

func _sell() -> void:
	var total := 0
	for name in collected.keys():
		var kind: int = OreScript.LABELS.find(name)
		if kind != -1:
			total += int(collected[name]) * int(OreScript.VALUES[kind])
	if total == 0:
		hud.show_notice("No ore in your cargo yet.")
		return
	credits += total
	collected.clear()
	hud.show_notice("Sold mineral cargo for $%d!" % total, 3.0)
	_update_hud()

func _upgrade() -> void:
	var price := _upgrade_cost()
	if credits < price:
		hud.show_notice("Upgrade needs $%d (you have $%d)" % [price, credits])
		return
	credits -= price
	upgrade_level += 1
	hud.show_notice("Pickaxe Level %d! Faster, wider digging." % upgrade_level, 3.0)
	_update_hud()

func _upgrade_cost() -> int:
	return 20 * upgrade_level * upgrade_level

func _update_hud() -> void:
	hud.set_hud(credits, upgrade_level, _upgrade_cost(), rock_count, collected)
