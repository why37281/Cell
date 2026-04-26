extends Node


# 拦截成员变量的赋值
func _set(property, value):
	Console.vars[property] = value
	return true   # 告诉引擎属性已被处理

# 拦截成员变量的读取
func _get(property):
	return Console.vars.get(property, null)

func print_error(error:String):
	Console.print_error(error)

func print_info(info:String):
	Console.print_info(info)

func print_warn(warn:String):
	Console.print_warn(warn)
