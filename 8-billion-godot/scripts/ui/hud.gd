extends CanvasLayer

@onready var label: Label = $MarginContainer/VBoxContainer/Stats
@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/Health

func update_stats(health: int, souls: int, defeated: int, buildings: int, indoors: bool) -> void:
	health_bar.value = health
	label.text = "Defeated: %d   Souls: %d   Buildings: %d/12   %s" % [defeated, souls, buildings, "INTERIOR" if indoors else "CITY"]
