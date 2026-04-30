extends Node

# 存储可执行文件目录
var exe_dir: String = ""

func _ready() -> void:
	# 获取可执行文件路径
	var exe_path = OS.get_executable_path()
	
	if exe_path:  # 如果是导出后的可执行文件
		exe_dir = exe_path.get_base_dir()
	else:  # 在编辑器内运行
		#exe_dir = OS.get_user_data_dir()  # 使用用户数据目录
		exe_dir = "res://editor_path/"
