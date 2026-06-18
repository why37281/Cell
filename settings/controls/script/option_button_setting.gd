# OptionButtonSetting.gd
class_name OptionButtonSetting
extends BaseSettingControl

@export var options: PackedStringArray = []

@onready var option_button: OptionButton = $OptionButton

func _ready():
	for opt in options:
		option_button.add_item(opt)
	super._ready()

func apply_value(value: Variant):
	for i in range(option_button.item_count):
		if option_button.get_item_text(i) == str(value):
			option_button.select(i)
			return

func get_current_value() -> Variant:
	return option_button.get_item_text(option_button.selected)

func connect_value_changed_signal():
	option_button.item_selected.connect(_on_value_changed)
