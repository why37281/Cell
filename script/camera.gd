extends Camera2D

# 拖动相关变量
var is_dragging: bool = false
var drag_start_mouse_pos: Vector2 = Vector2.ZERO
var drag_start_camera_pos: Vector2 = Vector2.ZERO

#限制相机移动的范围（世界坐标边界）(TODO)
var drag_limits: Rect2 = Rect2()

func _ready():
	pass
	# 设置相机初始位置（例如显示网格中央）
	# 假设网格尺寸 500x500，格子大小 64，原点在左上角
	var grid_size_px = Vector2(500 * 64, 500 * 64)
	#position = grid_size_px / 2

	# 如果你需要限制相机移动范围，在这里设置边界
	# drag_limits = Rect2(Vector2.ZERO, grid_size_px)

func _input(event: InputEvent):
	# 监听鼠标按钮事件
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				# 开始拖动
				is_dragging = true
				drag_start_mouse_pos = event.position
				drag_start_camera_pos = position
				# 可选：改变鼠标光标样式
				Input.set_default_cursor_shape(Input.CURSOR_DRAG)
			else:
				# 结束拖动
				is_dragging = false
				Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	# 监听鼠标移动事件（仅在拖动时）
	if event is InputEventMouseMotion and is_dragging:
		# 计算鼠标移动的偏移量（屏幕坐标）
		var mouse_delta = event.position - drag_start_mouse_pos
		# 将偏移量转换到世界坐标（考虑相机缩放）
		var world_delta = mouse_delta / zoom
		# 更新相机位置：起始相机位置 - 偏移量
		var new_pos = drag_start_camera_pos - world_delta
		# 可选：应用边界限制
		if drag_limits != Rect2():
			# 获取当前视口大小（世界单位）
			var viewport_size = get_viewport().get_visible_rect().size / zoom
			# 限制相机位置不能使视口边缘超出地图边界
			var min_x = drag_limits.position.x + viewport_size.x / 2
			var max_x = drag_limits.end.x - viewport_size.x / 2
			var min_y = drag_limits.position.y + viewport_size.y / 2
			var max_y = drag_limits.end.y - viewport_size.y / 2
			new_pos.x = clamp(new_pos.x, min_x, max_x)
			new_pos.y = clamp(new_pos.y, min_y, max_y)
		position = new_pos

func _process(delta: float) -> void:
	pass
