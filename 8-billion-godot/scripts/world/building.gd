extends Node2D
class_name DestructibleBuilding

signal destroyed(building: DestructibleBuilding)

@export var max_health: int = 100
var health: int = 100
var is_destroyed: bool = false

func _ready() -> void:
	health = max_health

func apply_damage(amount: int) -> void:
	if is_destroyed:
		return
	health = maxi(0, health - amount)
	$HealthBar.value = health
	if health == 0:
		is_destroyed = true
		$Sprite2D.modulate = Color("#62545d")
		$Sprite2D.scale.y = 0.17
		$Sprite2D.position.y = -15.0
		$HealthBar.visible = false
		destroyed.emit(self)

func can_enter(world_x: float) -> bool:
	return not is_destroyed and absf(global_position.x - world_x) < 100.0
