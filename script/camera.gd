extends Camera2D

# 缩放速度常量
const ZOOM_SPEED = 0.1          # 滚轮每格缩放的比例
const KEY_ZOOM_SPEED = 0.05     # 键盘每次缩放的步长

# 相机最小/最大缩放限制（防止太近或太远）
const MIN_ZOOM = Vector2(0.1, 0.1)
const MAX_ZOOM = Vector2(5.0, 5.0)

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

		# ---- 滚轮缩放（围绕鼠标位置） ----
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_point(ZOOM_SPEED, event.position)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_point(-ZOOM_SPEED, event.position)

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

	# ---- 键盘缩放（Ctrl + 加号 / 减号） ----
	if event is InputEventKey and event.pressed:
		if event.ctrl_pressed or event.meta_pressed:  # meta_pressed 用于 macOS
			if event.keycode == KEY_EQUAL or event.keycode == KEY_PLUS:
				# 围绕屏幕中心缩放（因为没有鼠标位置）
				_zoom_at_center(KEY_ZOOM_SPEED)
			elif event.keycode == KEY_MINUS:
				_zoom_at_center(-KEY_ZOOM_SPEED)

# 围绕给定屏幕坐标进行缩放
func _zoom_at_point(zoom_delta: float, screen_point: Vector2):
	var old_zoom = zoom
	var new_zoom = (zoom + Vector2(zoom_delta, zoom_delta)).clamp(MIN_ZOOM, MAX_ZOOM)
	if new_zoom == old_zoom:
		return

	# 计算缩放中心的世界坐标（缩放前）
	var world_point_before = get_global_mouse_position()  # 直接获取最方便

	# 应用新缩放
	zoom = new_zoom

	# 计算缩放后的世界坐标，并调整相机位置使 world_point 保持在相同的屏幕位置
	var world_point_after = get_canvas_transform().affine_inverse() * screen_point
	position += world_point_before - world_point_after

# 围绕视口中心缩放（用于键盘快捷键）
func _zoom_at_center(zoom_delta: float):
	var old_zoom = zoom
	var new_zoom = (zoom + Vector2(zoom_delta, zoom_delta)).clamp(MIN_ZOOM, MAX_ZOOM)
	if new_zoom == old_zoom:
		return

	var viewport_size = get_viewport().get_visible_rect().size
	var center_screen = viewport_size / 2.0
	# 中心点缩放等价于围绕屏幕中心缩放
	var world_center_before = get_canvas_transform().affine_inverse() * center_screen
	zoom = new_zoom
	var world_center_after = get_canvas_transform().affine_inverse() * center_screen
	position += world_center_before - world_center_after

func _process(delta: float) -> void:
	pass
