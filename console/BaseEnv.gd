extends Node

var _console  # 引用自动加载的 Console

func init(console):
	_console = console

# 拦截成员变量的赋值
func _set(property, value):
	_console.vars[property] = value
	return true   # 告诉引擎属性已被处理

# 拦截成员变量的读取
func _get(property):
	return _console.vars.get(property, null)
