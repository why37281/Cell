# Memory

## 项目信息
- **项目名称**: Cell-1 (Cell: a game)
- **引擎版本**: Godot 4.6+
- **渲染器**: Mobile (Direct3D 12)
- **物理引擎**: Jolt Physics (3D)
- **目标平台**: Windows (Mobile rendering)

## 目录结构
```
cell-1/
├── addons/                     # 插件目录
│   └── godot-git-plugin/       # Git 集成插件 (GDExtension)
├── console/                    # 游戏内调试控制台
│   ├── Console.gd              # 控制台单例 (Autoload)
│   ├── BaseEnv.gd              # 用户代码执行环境基类
│   ├── console_window.tscn     # 控制台窗口场景
│   └── console_window.gd       # 控制台窗口 UI 逻辑
├── scene/                      # 场景文件
│   ├── start.tscn              # 主菜单场景
│   ├── game.tscn               # 游戏场景
│   └── settings.tscn           # 设置场景
├── script/                     # 脚本文件
│   ├── start.gd                # 主菜单逻辑
│   ├── game.gd                 # 游戏控制器 (占位符)
│   ├── camera.gd               # 摄像机控制（拖拽+缩放）
│   ├── path.gd                 # 文件路径解析 (Autoload)
│   └── settings/               # 设置子系统
│       ├── settings.gd         # 设置界面逻辑
│       ├── setting_items.gd    # 设置项内存管理 (Autoload)
│       └── settings_IO.gd      # 设置 JSON 持久化 (Autoload)
├── resource/                   # 游戏资源
│   └── picture/
│       └── tile/
│           └── board.png       # TileMap 瓦片纹理 (64x64)
├── test/
│   └── 111.loadable            # 控制台可加载日志测试文件（当前为空）
├── editor_path/                # 编辑器运行时日志导出目录
├── project.godot               # 项目配置
└── memory.md                   # 项目记忆文档
```

## Autoload 单例
- **Console** (`console/Console.gd`): 游戏内开发者控制台系统
  - 自定义 `ConsoleLogger` 拦截引擎日志/错误/警告
  - 动态编译用户输入的 GDScript 代码 (`execute_full`)
  - 持久化变量存储 (`vars`)
  - 日志自动导出 (.txt / .loadable JSON-lines 格式)
  - F12 热键打开控制台窗口，首次弹出 WarnWindow 提示注意事项
- **Path** (`script/path.gd`): 获取可执行文件目录，编辑器中回退到 `res://editor_path/`
- **SettingItems** (`script/settings/setting_items.gd`): 设置项内存管理
  - 维护 6 项默认值字典（音量、全屏、分辨率、语言等）
  - 提供 `get_value` / `set_value` / `reset_all`，未知 key 会 warn
  - 批量设置支持深拷贝防止引用污染
- **SettingsIO** (`script/settings/settings_IO.gd`): 设置 JSON 持久化
  - `save_file()` → `settings.json`（带缩进）
  - `load_file()` → 解析后调用 `SettingItems.set_all()`
  - 文件路径依赖 `Path.exe_dir`

## 主要场景

### start.tscn (主菜单)
- Control 根节点，中文 UI
- 标题 "Cell"，三个按钮：开始/设置/退出
- 开始 → `game.tscn`（`change_scene_to_file`）
- 设置 → `settings.tscn`（`change_scene_to_file`）
- 退出 → `get_tree().quit()`

### settings.tscn (设置)
- Control 根节点，标题 "设置"
- 返回按钮 → `start.tscn`（`change_scene_to_file`）
- 设置项的 UI 控件尚未绑定到 SettingItems

### game.tscn (游戏主场景)
- Node2D 根节点，含 HUD (CanvasLayer)、Camera2D、TileMapLayer
- TileMapLayer 使用 board.png，tile_size 64x64
- Camera2D 绑定 camera.gd，支持右键拖拽平移、滚轮缩放（围绕鼠标）、Ctrl+/- 键盘缩放（围绕中心）
- 缩放范围 0.1x ~ 5.0x，边界限制逻辑已编写但未启用（drag_limits 为默认空值）

### console_window.tscn (控制台窗口)
- Window 根节点，初始隐藏
- VSplitContainer 布局：上为 RichTextLabel 输出区，下为 TextEdit 输入区和按钮栏
- 按钮：运行/导出为文本文件/导出为可加载文件/加载/清除
- 子窗口：FileDialog、ConfirmWindow（清除确认）、WarnWindow

## 函数总览

### script/game.gd
> extends `Node2D` — 游戏主场景控制器（占位符）

| 函数 | 用途 |
|------|------|
| `_ready()` | 占位符 |
| `_process(delta)` | 占位符 |

---

### script/start.gd
> extends `Control` — 主菜单界面逻辑

| 函数 | 用途 |
|------|------|
| `_ready()` | 占位符 |
| `_process(delta)` | 占位符 |
| `_on_exit_pressed()` | 退出按钮回调，调用 `get_tree().quit()` |
| `_on_start_pressed()` | 开始按钮回调，`change_scene_to_file("res://scene/game.tscn")` |
| `_on_settings_pressed()` | 设置按钮回调，`change_scene_to_file("res://scene/settings.tscn")` |

---

### script/camera.gd
> extends `Camera2D` — 右键拖拽平移 + 滚轮/键盘缩放

| 函数 | 用途 |
|------|------|
| `_ready()` | 初始化（含被注释的网格居中与边界限制代码） |
| `_input(event)` | 右键按下/松开 → 开始/结束拖拽；拖拽中移动鼠标 → 计算世界坐标偏移（含缩放补偿），更新摄像机位置，依据 `drag_limits` 裁剪。滚轮上下 → `_zoom_at_point()`。Ctrl + =/- → `_zoom_at_center()` |
| `_zoom_at_point(zoom_delta, screen_point)` | 围绕给定屏幕坐标缩放，保持缩放中心世界坐标不变 |
| `_zoom_at_center(zoom_delta)` | 围绕视口中心缩放（键盘快捷键用） |
| `_process(delta)` | 占位符 |

---

### script/path.gd (Autoload: `Path`)
> extends `Node` — 解析可执行文件目录路径

| 函数 | 用途 |
|------|------|
| `_ready()` | 导出模式：设置 `exe_dir` 为可执行文件所在目录；编辑器模式：回退为 `res://editor_path/` |

---

### script/settings/settings.gd
> extends `Control` — 设置界面逻辑

| 函数 | 用途 |
|------|------|
| `_ready()` | 占位符 |
| `_process(delta)` | 占位符 |
| `_on_back_pressed()` | 返回按钮回调，`change_scene_to_file("res://scene/start.tscn")` |

---

### script/settings/setting_items.gd (Autoload: `SettingItems`)
> extends `Node` — 设置项内存管理

| 函数 | 用途 |
|------|------|
| `_ready()` | 调用 `reset_all()` 加载默认值 |
| `get_value(id)` | 获取指定设置项的当前值 |
| `set_value(id, value)` | 设置指定设置项的值，未知 key 会 warn |
| `get_keys()` | 返回所有设置项的 key 列表 |
| `reset_item(id)` | 将指定项重置为默认值 |
| `reset_all()` | 将所有项重置为默认值（深拷贝 `DEFAULTS`） |
| `set_all(data)` | 批量设置（从文件加载时使用），带深拷贝防引用污染 |
| `_deep_copy(value)` | 递归深拷贝：处理 Dictionary 和 Array，其他类型直接返回 |

---

### script/settings/settings_IO.gd (Autoload: `SettingsIO`)
> extends `Node` — 设置 JSON 持久化

| 函数 | 用途 |
|------|------|
| `save_file()` | 将 `SettingItems._values` 序列化为 JSON 写入 `settings.json`（带缩进） |
| `load_file()` | 从 `settings.json` 读取并解析 JSON，调用 `SettingItems.set_all()` 加载 |

---

### console/Console.gd (Autoload: `Console`)
> extends `Node` — 游戏内开发者控制台核心

#### #region 导出函数
| 函数 | 用途 |
|------|------|
| `_check_auto_export()` | 检查内存日志行数：当自上次导出后新增 ≥ `AUTO_EXPORT_CHUNK`(500) 行时触发自动导出 |
| `_auto_export()` | 将上次导出索引后的新日志追加写入可读文本文件（`console_log.txt`），更新导出指针 |
| `_append_to_file_readable(entries)` | 按类型写前缀（`● ERROR:` / `● WARN:`）将日志数组追加写入文本文件 |
| `export_logs_to_file()` | 将全部日志以 JSON-lines 格式导出到 `console_log.loadable` |

#### #region 日志管理函数
| 函数 | 用途 |
|------|------|
| `load_logs_from_file(file_path, clear_existing)` | 从 `.loadable` 文件逐行解析 JSON，加载到 `log_entries`；可清空已有日志或追加 |
| `clear_logs()` | 清空全部内存日志与 RichTextLabel 显示，重置导出指针 |
| `_rebuild_display()` | 遍历 `log_entries` 重建 RichTextLabel 的 BBCode 输出（红/黄/白按级别着色） |
| `_add_log_line(type, text)` | 将一条日志追加到 `log_entries` 数组，随后调用 `_check_auto_export()` |

#### #region Logger
| 函数 | 用途 |
|------|------|
| `ConsoleLogger._log_error(function, file, line, code, rationale, editor_notify, error_type, script_backtraces)` | 自定义 Logger 子类：拦截引擎脚本错误/运行时错误/警告，格式化描述与位置信息，线程安全地委托 `_update_console` 输出 |
| `ConsoleLogger._log_message(message, error)` | 拦截系统级日志消息，格式化后委托输出 |
| `_on_script_error(error, file, line)` | 遗留函数（未被任何信号连接），格式化运行时错误并调用 `print_error`。实际生效的是 `ConsoleLogger._log_error` |
| `_update_console(msg, method)` | 线程安全入口：检查窗口有效性后动态调用 `print_info` / `print_error` / `print_warn` |

#### #region 输出函数
| 函数 | 用途 |
|------|------|
| `print_info(info)` | 将 info 文本写入 `log_entries`（类型 `"info"`），追加到 RichTextLabel（白色） |
| `print_error(error)` | 将 error 文本写入 `log_entries`（类型 `"error"`），追加到 RichTextLabel（红色，`● ERROR:` 前缀） |
| `print_warn(warn)` | 将 warn 文本写入 `log_entries`（类型 `"warn"`），追加到 RichTextLabel（黄色，`● WARN:` 前缀） |

#### 其他函数
| 函数 | 用途 |
|------|------|
| `_ready()` | 创建 `execute_node` 并挂载 BaseEnv 脚本；预加载实例化控制台窗口（初始隐藏）；注册 `ConsoleLogger` 到 `OS.add_logger` |
| `execute_full(code)` | 将用户输入包装为继承 BaseEnv 的临时 GDScript 文件（`user://temp_script.gd`），忽略缓存加载后替换到 `execute_node` 上，调用 `run()`，最后清理临时文件 |
| `_input(event)` | 监听 F12 按键，弹出控制台窗口；首次弹出附带 WarnWindow 警告提示 |

---

### console/BaseEnv.gd
> extends `Node` — 用户代码执行环境基类，实现变量跨执行持久化

| 函数 | 用途 |
|------|------|
| `_set(property, value)` | 拦截属性赋值，存入 `Console.vars[property]`，返回 `true` 告知引擎已处理 |
| `_get(property)` | 拦截属性读取，返回 `Console.vars.get(property, null)` |
| `print_error(error)` | 委托到 `Console.print_error(error)` |
| `print_info(info)` | 委托到 `Console.print_info(info)` |
| `print_warn(warn)` | 委托到 `Console.print_warn(warn)` |

---

### console/console_window.gd
> extends `Window` — 控制台窗口 UI 逻辑

| 函数 | 用途 |
|------|------|
| `_ready()` | 占位符 |
| `_process(delta)` | 占位符 |
| `_on_text_edit_focus_entered()` | TextEdit 获得焦点时启用当前行高亮 |
| `_on_text_edit_focus_exited()` | TextEdit 失焦时禁用当前行高亮 |
| `_on_close_requested()` | 隐藏 WarnWindow 和自身窗口 |
| `append_output(text)` | 增量追加文本到 RichTextLabel |
| `set_output(text)` | 全量替换 RichTextLabel 显示内容 |
| `clear_output()` | 清空 RichTextLabel |
| `_on_run_pressed()` | 获取 TextEdit 中代码，清空输入框，调用 `Console.execute_full(code)` |
| `_on_export_pressed()` | 触发 `Console._auto_export()` 导出文本日志 |
| `_on_export_loadable_pressed()` | 触发 `Console.export_logs_to_file()` 导出可加载文件 |
| `_on_load_pressed()` | 显示 FileDialog 文件选择器 |
| `_on_clean_pressed()` | 弹出 ConfirmWindow 确认清除对话框 |
| `_on_file_dialog_file_selected(path)` | 调用 `Console.load_logs_from_file(path)` 加载所选文件 |
| `_on_confirmation_dialog_confirmed()` | 占位符（仅打印 "confirm"） |
| `_on_confirm_pressed()` | 隐藏确认窗口，清空 `Console.log_entries` 并重建显示 |
| `_on_cancel_pressed()` | 隐藏确认窗口 |
| `_on_window_close_requested()` | 隐藏 WarnWindow |

## 插件依赖
- **godot-git-plugin**: Godot 官方 Git 集成插件 (GDExtension, 支持 4.2.0+)
  - 平台: Windows (x86_64), Linux (x86_64), macOS (universal)
  - 依赖: godot-cpp, libgit2, libssh2, OpenSSL

## 开发状态
- [x] 项目基础结构搭建
- [x] Git 版本控制配置
- [x] 主菜单场景创建
- [x] 游戏内调试控制台系统
- [x] 摄像机控制（拖拽 + 滚轮缩放 + 键盘缩放）
- [x] 设置系统（SettingItems 内存管理 + SettingsIO JSON 持久化）
- [x] TileMap 基础搭建
- [x] 场景跳转（开始→game / 设置→settings / 返回→start）
- [x] 设置界面
- [ ] 设置 UI 控件与 SettingItems 绑定
- [ ] 游戏核心逻辑实现
- [ ] HUD 内容填充
- [ ] 摄像机边界限制启用

## 备注
- 项目使用中文 UI (目标用户为中文用户)
- 目前处于早期开发阶段，大部分游戏功能为占位符
- 使用 Godot UID 系统管理资源引用