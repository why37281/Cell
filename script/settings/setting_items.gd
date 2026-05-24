# SettingItems.gd (自动加载)
extends Node

# 默认值字典：所有设置项的初始值
const DEFAULTS: Dictionary = {
	"master_volume": 1.0,
	"fullscreen": false,
	"resolution": "1920x1080",
	"language": "zh_CN",
	"music_volume": 0.8,
	"sfx_volume": 1.0,
}

# 当前值字典
var _values: Dictionary = {}

func _ready():
	reset_all()

# 获取当前值
func get_value(id: String):
	return _values.get(id, null)

# 设置值
func set_value(id: String, value):
	if _values.has(id):
		_values[id] = value
	else:
		push_warning("SettingItems: 未知设置项 '%s'" % id)
		Console.print_error("SettingItems: 未知设置项 '%s'" % id)

# 获取所有键
func get_keys() -> Array:
	return _values.keys()

# 重置某一项为默认值
func reset_item(id: String):
	if DEFAULTS.has(id):
		_values[id] = DEFAULTS[id]

# 重置所有
func reset_all():
	_values = DEFAULTS.duplicate(true)

# 递归深拷贝：仅处理字典和普通数组，其他类型直接返回（视为不可变或无需拷贝）
func _deep_copy(value: Variant) -> Variant:
	if value is Dictionary:
		var new_dict: Dictionary = {}
		for key in value:
			new_dict[key] = _deep_copy(value[key])
		return new_dict

	if value is Array:
		var new_arr: Array = []
		for elem in value:
			new_arr.append(_deep_copy(elem))
		return new_arr

	# 基础类型、PackedArray、Object、Resource 等全部直接返回
	return value

# 批量设置（从文件加载时使用）
func set_all(data: Dictionary):
	for key in data.keys():
		if _values.has(key):
			# 对值进行深拷贝，避免引用类型（字典、数组）被外部修改影响
			_values[key] = _deep_copy(data[key])
