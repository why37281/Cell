# CheckBoxSetting.gd — 多选复选框控件
# 存储格式：Array（选中的 option 值列表）
class_name CheckBoxSetting
extends BaseSettingControl

@export var options: PackedStringArray = []   # 选项的值（存储用）
@export var labels: PackedStringArray = []    # 选项的显示文本

@onready var checkbox_container: VBoxContainer = $CheckboxContainer

func _ready():
	assert(options.size() > 0, "CheckBoxSetting: options 不能为空")
	_build_checkboxes()
	super._ready()

# 构建所有 CheckBox 节点
func _build_checkboxes():
	for i in range(options.size()):
		var cb = CheckBox.new()
		cb.text = labels[i] if i < labels.size() else options[i]
		cb.name = "CheckBox_" + options[i]
		checkbox_container.add_child(cb)

func apply_value(value: Variant):
	var checked_array: Array = value if value is Array else []
	for i in range(options.size()):
		var cb: CheckBox = checkbox_container.get_child(i)
		cb.button_pressed = options[i] in checked_array

func get_current_value() -> Variant:
	var checked: Array = []
	for i in range(options.size()):
		var cb: CheckBox = checkbox_container.get_child(i)
		if cb.button_pressed:
			checked.append(options[i])
	return checked

func connect_value_changed_signal():
	for i in range(options.size()):
		var cb: CheckBox = checkbox_container.get_child(i)
		cb.toggled.connect(_on_checkbox_toggled.bind(i))

func _on_checkbox_toggled(_pressed: bool, _index: int):
	_on_value_changed(null)
