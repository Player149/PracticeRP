extends Node2D

@export var lifetime: float = 0.55
@export var count: int = 12
var particles: Array[Dictionary] = []
var elapsed: float = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in range(count):
		particles.append({
			"pos": Vector2.ZERO,
			"vel": Vector2(rng.randf_range(-140.0, 140.0), rng.randf_range(-230.0, -35.0)),
			"size": rng.randf_range(2.0, 5.0)
	})

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
		return
	for i in range(particles.size()):
		var particle: Dictionary = particles[i]
		particle["pos"] = particle["pos"] + particle["vel"] * delta
		particle["vel"] = particle["vel"] + Vector2(0.0, 400.0 * delta)
		particles[i] = particle
	queue_redraw()

func _draw() -> void:
	var opacity: float = 1.0 - elapsed / lifetime
	for particle in particles:
		draw_circle(particle["pos"], particle["size"] * opacity, Color(0.95, 0.27, 0.42, opacity))
