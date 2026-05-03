extends Node

var vars: Dictionary = {}          # 所有持久化变量存在这里
var execute_node: Node = null      # 一直存活的执行节点
var console_window : Window
# 新增：记录已经自动导出到文件的最后一条内存索引（-1 表示未导出过）
var _last_exported_index: int = -1

# 日志自动导出相关常量
const AUTO_EXPORT_LINES_THRESHOLD = 1000
const AUTO_EXPORT_CHUNK = 500
const LOG_FILE_NAME = "console_log.txt"

# 修改日志存储为字典数组：{ "type": "error"/"warn"/"info", "text": "消息内容" }
var log_entries: Array[Dictionary] = []
var total_chars: int = 0  # 可保留用于其他限制，非必须

func _check_auto_export() -> void:
	# 当内存日志行数比上次导出时多出 AUTO_EXPORT_CHUNK 行，就触发自动导出
	if log_entries.size() - (_last_exported_index + 1) >= AUTO_EXPORT_CHUNK:
		_auto_export()

func _auto_export() -> void:
	# 导出从上一次导出之后到现在的所有新日志
	var start_index = _last_exported_index + 1
	var to_export = log_entries.slice(start_index, log_entries.size())
	
	if to_export.is_empty():
		return

	_append_to_file_readable(to_export)
	_last_exported_index = log_entries.size() - 1  # 更新指针
	print("[Console] 已自动导出 %d 行日志（索引 %d - %d）" % [to_export.size(), start_index, _last_exported_index])
	
# 将日志导出到指定文件（追加模式）
func export_logs_to_file(file_name: String) -> void:
	if log_entries.is_empty():
		print_info("没有可导出的日志。")
		return

	var dir = Path.exe_dir
	var file_path = dir.path_join(file_name)
	DirAccess.make_dir_recursive_absolute(dir)

	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			push_error("无法创建日志文件: " + file_path)
			return
	file.seek_end()

	for entry in log_entries:
		# 将字典序列化为 JSON 字符串，写入一行
		file.store_string(JSON.stringify(entry) + "\n")

	file.close()
	print_info("日志已导出到 " + file_name)

func load_logs_from_file(file_name: String, clear_existing: bool = false) -> void:
	var dir = Path.exe_dir
	var file_path = dir.path_join(file_name)

	if not FileAccess.file_exists(file_path):
		print_error("日志文件不存在: " + file_name)
		return

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print_error("无法打开日志文件: " + file_name)
		return

	var entries: Array[Dictionary] = []
	while not file.eof_reached():
		var line = file.get_line()
		if line.is_empty():
			continue
		var json = JSON.new()
		var err = json.parse(line)
		if err == OK:
			var data = json.get_data()
			if data is Dictionary and data.has("type") and data.has("text"):
				entries.append(data)
	file.close()

	if clear_existing:
		log_entries = entries
	else:
		log_entries.append_array(entries)

	_rebuild_display()
	print_info("已从 %s 加载 %d 条日志" % [file_name, entries.size()])

func _append_to_file_readable(entries: Array) -> void:
	var dir = Path.exe_dir
	var file_path = dir.path_join(LOG_FILE_NAME)

	# 确保目录存在
	DirAccess.make_dir_recursive_absolute(dir)

	var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(file_path, FileAccess.WRITE)
		if file == null:
			push_error("无法创建日志文件: " + file_path)
			return
	file.seek_end()

	for entry in entries:
		var line: String
		match entry["type"]:
			"error": line = "● ERROR: " + entry["text"]
			"warn":   line = "● WARN: " + entry["text"]
			_:        line = entry["text"]
		file.store_string(line + "\n")

	file.close()

func _rebuild_display() -> void:
	var rtl = console_window.rich_text
	rtl.clear()
	for entry in log_entries:
		var safe_text = entry["text"].replace("[", "[lb]").replace("]", "[rb]")
		match entry["type"]:
			"error":
				rtl.append_text("[color=red][b]● ERROR: [/b]" + safe_text + "[/color]\n")
			"warn":
				rtl.append_text("[color=yellow][b]● WARN: [/b]" + safe_text + "[/color]\n")
			_:  # info
				rtl.append_text("[color=white]" + safe_text + "[/color]\n")

func _add_log_line(type: String, text: String) -> void:
	log_entries.append({"type": type, "text": text})
	_check_auto_export()

class ConsoleLogger extends Logger:
	func _log_error(function: String, file: String, line: int, code: Variant, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array) -> void:
		var desc = ""
		var print_func = "print_info"

		# 1. rationale 是官方给的描述，很多情况下是空的
		desc = rationale

		# 2. code 实际上是错误描述字符串（引擎版本差异）
		if desc.is_empty() and code != null:
			desc = str(code)   # 直接转成字符串

		# 3. 还是空的话，从调用栈里取最顶层的函数名
		if desc.is_empty() and not script_backtraces.is_empty():
			desc = str(script_backtraces[0])  # 取最近的一条

		# 4. 彻底没救了
		if desc.is_empty():
			return  # 忽略无意义的消息

		# 5. 根据错误类型决定前缀和输出方法
		match error_type:
			Logger.ERROR_TYPE_SCRIPT:
				desc = "脚本错误: " + desc + "\n  位置: " + file.get_file() + ":" + str(line)
				print_func = "print_error"
			Logger.ERROR_TYPE_ERROR:
				desc = "运行时错误: " + desc + "\n  位置: " + file.get_file() + ":" + str(line)
				print_func = "print_error"
			Logger.ERROR_TYPE_WARNING:
				desc = "警告: " + desc + "\n  位置: " + file.get_file() + ":" + str(line)
				print_func = "print_warn"
			_:
				return

		# 线程安全地输出到控制台
		Console.call_deferred("_update_console", desc, print_func)

	func _log_message(message: String, error: bool) -> void:
		if error:
			Console.call_deferred("_update_console", "[color=gray]系统: " + message + "[/color]", "print_error")

var _logger: ConsoleLogger = null

func _on_script_error(error: String, file: String, line: int) -> void:
	# 将错误信息格式化并输出到控制台
	var msg = "运行时错误 @%s:%d - %s" % [file.get_file(), line, error]
	print_error(msg)

# 3. 添加一个线程安全的方法来更新控制台 UI
func _update_console(msg: String, method: String = "print_info"):
	# 确保窗口和 RichTextLabel 实例有效
	if not is_instance_valid(console_window) or not is_instance_valid(console_window.rich_text):
		return
	
	# 动态调用不同的输出方法 (print_error, print_warn, print_info)
	if has_method(method):
		call(method, msg)
	else:
		print_info(msg) # 备用

func _ready():
	# 创建执行节点，挂上 BaseEnv 脚本，并传入 Console 自身
	execute_node = Node.new()
	execute_node.set_script(load("res://console/BaseEnv.gd"))
	add_child(execute_node)    # 挂在单例下，保证存活
	
	console_window = preload("res://console/console_window.tscn").instantiate()
	console_window.hide()              # 初始隐藏
	add_child(console_window)          # 挂在单例下
	
	_logger = ConsoleLogger.new()
	OS.add_logger(_logger)
	print("[Console] 自定义 Logger 已注册。")
	

# 执行用户输入的完整 GDScript 代码
func execute_full(code: String):
	# 生成临时脚本，继承自 BaseEnv，覆盖 run() 方法
	var full_code = """extends "res://console/BaseEnv.gd"

func run():
	%s
	return
""" % code

	var file_path = "user://temp_script.gd"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		print_error("无法创建临时文件")
		return
	file.store_string(full_code)
	file.close()

	# 忽略缓存，每次获取最新内容
	var new_script = ResourceLoader.load(file_path, "GDScript", ResourceLoader.CACHE_MODE_IGNORE)
	if new_script == null:
		print_error("脚本编译失败")
		return

	# 关键：直接替换执行节点的脚本
	execute_node.set_script(new_script)
	var result = null
	
	if execute_node.has_method("run"):
		result = execute_node.call("run")

	# 清理临时文件
	DirAccess.remove_absolute(file_path)
	print_info("Done.")

func print_info(info: String):
	_add_log_line("info", info)
	# 将 info 中的 [ ] 转义为 [lb] 和 [rb]
	var safe_info = info.replace("[", "[lb]").replace("]", "[rb]")
	console_window.rich_text.append_text(safe_info + "\n")

func print_error(error: String):
	_add_log_line("error", error)
	var safe_error = error.replace("[", "[lb]").replace("]", "[rb]")
	console_window.rich_text.append_text("[color=red][b]● ERROR: [/b]" + safe_error + "[/color]\n")

func print_warn(warn: String):
	_add_log_line("warn", warn)
	var safe_warn = warn.replace("[", "[lb]").replace("]", "[rb]")
	console_window.rich_text.append_text("[color=yellow][b]● WARN: [/b]" + safe_warn + "[/color]\n")

func _input(event):
	# 只处理按键按下事件
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		# 切换窗口可见性
		if console_window.visible:
			console_window.hide()
		else:
			console_window.show()  # 或 show()
		# 接受事件，阻止继续传播（可选）
		get_viewport().set_input_as_handled()
