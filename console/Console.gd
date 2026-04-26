extends Node

var vars: Dictionary = {}          # 所有持久化变量存在这里
var execute_node: Node = null      # 一直存活的执行节点
var log_entries : Array[String] = []
var console_window : Window

var _previous_error_handler: Callable = Callable()

func _on_script_error(error: String, file: String, line: int) -> void:
	# 将错误信息格式化并输出到控制台
	var msg = "运行时错误 @%s:%d - %s" % [file.get_file(), line, error]
	print_error(msg)

func _ready():
	# 创建执行节点，挂上 BaseEnv 脚本，并传入 Console 自身
	execute_node = Node.new()
	execute_node.set_script(load("res://console/BaseEnv.gd"))
	add_child(execute_node)    # 挂在单例下，保证存活
	
	console_window = preload("res://console/console_window.tscn").instantiate()
	console_window.hide()              # 初始隐藏
	add_child(console_window)          # 挂在单例下
	

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
	
	_previous_error_handler = Debug.get_error_handler()
	Debug.set_error_handler(_on_script_error)
	
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
