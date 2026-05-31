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
		Console.print_warn("SettingItems: 未知设置项 '%s'" % id)

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

# 递归深拷贝：字典和各类数组递归处理，其他类型直接返回
func _deep_copy(value: Variant) -> Variant:
	match typeof(value):
		TYPE_DICTIONARY:
			var new_dict: Dictionary = {}
			for key in value:
				new_dict[key] = _deep_copy(value[key])
			return new_dict

		TYPE_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_INT32_ARRAY, \
		TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, \
		TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, \
		TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_BYTE_ARRAY:
			var new_array: Array = []
			for element in value:
				new_array.append(_deep_copy(element))
			return new_array

		_:
			return value

# 批量设置（从文件加载时使用）
func set_all(data: Dictionary):
	for key in data.keys():
		if _values.has(key):
			# 对值进行深拷贝，避免引用类型（字典、数组）被外部修改影响
			_values[key] = _deep_copy(data[key])
