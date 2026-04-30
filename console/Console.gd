extends Node

var vars: Dictionary = {}          # 所有持久化变量存在这里
var execute_node: Node = null      # 一直存活的执行节点
var log_entries : Array[String] = []
var console_window : Window

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

func print_error(error:String):
	print("pushed error")
	console_window.rich_text.append_text("[color=red][b] ● ERROR : [/b]" + error + "[/color]\n")

func print_info(info:String):
	console_window.rich_text.append_text("[color=gray]" + info + "[/color]\n")

func print_warn(warn:String):
	console_window.rich_text.append_text("[color=yellow][b] ● WARN : [/b]" + warn + "[/color]\n")

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
