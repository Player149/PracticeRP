extends Node2D

signal health_changed(old_value, new_value)

var health  = 10

func take_damage(amount):
	var old_health = health
	health -= amount
	health_changed.emit(old_health, health)
