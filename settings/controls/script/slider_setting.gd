# SliderSetting.gd
class_name SliderSetting
extends BaseSettingControl

@export var min_value: float = 0.0
@export var max_value: float = 1.0
@export var step: float = 0.0

@onready var slider: HSlider = $MarginContainer/HSlider
func _ready():
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	super._ready()

func apply_value(value: Variant):
	slider.value = float(value)

func get_current_value() -> Variant:
	return slider.value

func connect_value_changed_signal():
	slider.value_changed.connect(_on_value_changed)
