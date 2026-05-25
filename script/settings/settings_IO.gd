# SettingsIO.gd (自动加载)
extends Node

const FILE_NAME = "settings.json"

# 保存到文件
func save_file():
	var dir = Path.exe_dir
	var file_path = dir.path_join(FILE_NAME)
	DirAccess.make_dir_recursive_absolute(dir)

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_error("SettingsIO: 无法写入 " + file_path)
		Console.print_error("SettingsIO: 无法写入 " + file_path)
		return

	var json_str = JSON.stringify(SettingItems._values, "\t")
	file.store_string(json_str)
	file.close()

# 从文件加载
func load_file():
	var file_path = Path.exe_dir.path_join(FILE_NAME)
	if not FileAccess.file_exists(file_path):
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("SettingsIO: 无法读取 " + file_path)
		Console.print_error("SettingsIO: 无法读取 " + file_path)
		return

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	if json.parse(json_str) != OK:
		push_error("SettingsIO: 文件格式错误")
		Console.print_error("SettingsIO: 文件格式错误")
		return

	var data = json.get_data()
	if typeof(data) == TYPE_DICTIONARY:
		SettingItems.set_all(data)
