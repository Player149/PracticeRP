extends CanvasLayer

signal speed_changed(value: float)

@onready var stats: Label = $MarginContainer/VBoxContainer/Stats
@onready var slider: HSlider = $MarginContainer/VBoxContainer/SpeedSlider
@onready var speed_label: Label = $MarginContainer/VBoxContainer/SpeedLabel

func _ready() -> void:
	slider.value_changed.connect(_on_speed_changed)
	_on_speed_changed(slider.value)

func set_speed(value: float) -> void:
	slider.value = value
	_on_speed_changed(value)

func _on_speed_changed(value: float) -> void:
	speed_label.text = "Movement speed: %d" % int(value)
	speed_changed.emit(value)

func update_stats(defeated: int, remaining: int) -> void:
	stats.text = "Dummies defeated: %d   Remaining: %d" % [defeated, maxi(0, remaining)]
