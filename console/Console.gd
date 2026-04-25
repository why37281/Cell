extends Node

var vars: Dictionary = {}          # 所有持久化变量存在这里
var execute_node: Node = null      # 一直存活的执行节点

func _ready():
	# 创建执行节点，挂上 BaseEnv 脚本，并传入 Console 自身
	execute_node = Node.new()
	execute_node.set_script(load("res://console/BaseEnv.gd"))
	execute_node.init(self)   # 手动调用 init 传入 self
	add_child(execute_node)    # 加入场景树，保证存活

# 执行用户输入的完整 GDScript 代码
func execute_full(code: String) -> Dictionary:
	# 生成临时脚本，继承自 BaseEnv，覆盖 run() 方法
	var full_code = """extends "res://BaseEnv.gd"

func run():
%s
""" % code

	var file_path = "user://temp_script.gd"
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "error": "无法创建临时文件"}
	file.store_string(full_code)
	file.close()

	var new_script = load(file_path)
	if new_script == null:
		return {"ok": false, "error": "脚本编译失败"}

	# 关键：直接替换执行节点的脚本
	execute_node.set_script(new_script)

	var result = null
	if execute_node.has_method("run"):
		result = execute_node.call("run")

	# 清理临时文件
	DirAccess.remove_absolute(file_path)
	return {"ok": true, "result": result}
