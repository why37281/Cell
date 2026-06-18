# ButtonGroupSetting.gd — 单选框（CheckButton 组）控件
# 存储格式：选中的 option 值（String）
class_name ButtonGroupSetting
extends BaseSettingControl

@export var options: PackedStringArray = []   # 选项的值（存储用）
@export var labels: PackedStringArray = []    # 选项的显示文本

@onready var radio_container: VBoxContainer = $RadioContainer

var _button_group: ButtonGroup

func _ready():
	assert(options.size() > 0, "ButtonGroupSetting: options 不能为空")
	_build_radio_buttons()
	super._ready()

# 构建所有 CheckButton 节点（共享 ButtonGroup）
func _build_radio_buttons():
	_button_group = ButtonGroup.new()
	for i in range(options.size()):
		var rb = CheckButton.new()
		rb.text = labels[i] if i < labels.size() else options[i]
		rb.name = "CheckButton_" + options[i]
		rb.button_group = _button_group
		radio_container.add_child(rb)

func apply_value(value: Variant):
	var val_str = str(value)
	for i in range(options.size()):
		var rb: CheckButton = radio_container.get_child(i)
		rb.button_pressed = (options[i] == val_str)

func get_current_value() -> Variant:
	for i in range(options.size()):
		var rb: CheckButton = radio_container.get_child(i)
		if rb.button_pressed:
			return options[i]
	return options[0] if options.size() > 0 else ""

func connect_value_changed_signal():
	for i in range(options.size()):
		var rb: CheckButton = radio_container.get_child(i)
		rb.toggled.connect(_on_radio_toggled.bind(i))

func _on_radio_toggled(_pressed: bool, _index: int):
	_on_value_changed(null)
