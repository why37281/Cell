# BaseSettingControl.gd
class_name BaseSettingControl
extends Container

@export var setting_key: String = ""
@export_multiline var description: String = ""

@onready var title_label: Label = $TitleLabel
@onready var desc_label: Label = $DescLabel

func _ready():
	custom_minimum_size.x = 400
	title_label.text = setting_key
	if description.is_empty():
		desc_label.visible = false
	else:
		desc_label.text = description
	apply_value(SettingItems.get_value(setting_key))
	connect_value_changed_signal()

# 覆盖：如何把值显示到控件上
func apply_value(value: Variant):
	pass

# 覆盖：如何从控件获取当前值
func get_current_value() -> Variant:
	return null

# 覆盖：连接控件的值改变信号到 _on_value_changed
func connect_value_changed_signal():
	pass

# 统一的保存逻辑
func _on_value_changed(_new_value: Variant):
	var val = get_current_value()
	SettingItems.set_value(setting_key, val)
	SettingsIO.save_file()
