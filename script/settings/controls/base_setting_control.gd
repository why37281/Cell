# BaseSettingControl.gd
class_name BaseSettingControl
extends Control

@export var setting_key: String = ""

func _ready():
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
	SettingsIO.save()
