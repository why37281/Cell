# Cell 架构文档

> 配套玩法文档 `DESIGN.md`（玩法唯一权威）。本文档只管**怎么搭**，不管玩法。
> 玩法改了改 `DESIGN.md`，结构改了改本文档，两边不互相抄。
>
> **引用约定**：写「设计文档 §8」= 指 `DESIGN.md` 第 8 节；
> 写「本文档 §4」= 指下面第 4 节。
>
> 状态：**待审**。审完之后按本文档 §13 的顺序建文件。

---

## 0. 术语约定（全篇按这张表读）

### 0.1 自己的模块名（中文为主，括号里是代码里用的标识符）

| 中文名 | 代码标识符 | 它是什么 |
|---|---|---|
| **地图数据** | `GridMap` | 格子账本：区域编号、受体标记、有没有细胞 |
| **模拟核心** | `Sim` | 每 1/20 秒算一次：能量收支、分裂、凋亡 |
| **时钟驱动** | `SimDriver` | 只管"该算第几次了"，倍速和暂停作用在它身上 |
| **倍速器** | `TimeScale` | 存 0 / 1 / 2 / 4 这一个数字，全场景只有它能改 |
| **编辑控制器** | `EditController` | 唯一允许往地图数据里写字的地方（左键画、右键擦） |
| **撤销栈** | `UndoStack` | 存 50 份数据层快照 |
| **定义表** | `Defs` | 开局扫 `resource/organelle/*.tres`，建 `id → 资源` 字典 |
| **进度存档** | `Progress` | 研究点、已解锁、已通关 |
| **关卡定义** | `LevelDef` | 一个 `Resource`：地图多大、目标、预置、解锁哪些工具 |
| **细胞器定义** | `OrganelleDef` | 一个 `Resource`：产能多少、维持多少、解锁要多少研究点 |
| **模式定义** | `PatternDef` | 一个 `Resource`：名字、颜色、装哪些细胞器 |
| **价目表** | Economy 字典 | 模拟核心唯一认识的输入，见 §5.2 |

### 0.2 概念名（这些词原来直接写了英文，现在给中文）

| 中文 | 原来写的英文 | 一句话 |
|---|---|---|
| **分字段整排存** | SoA（结构数组） | 不用 `Array[Cell]`，用一排 `PackedInt32Array` 按字段各存一排 |
| **待重画块** | dirty chunks | 地图按 32×32 分块，只有变过的块才重画 |
| **一帧一步** | tick | 模拟推进的最小单位，固定 1/20 秒 |
| **纯逻辑对象** | `RefCounted` 派生 | Godot 里"不是节点、不挂进场景树"的基类 |
| **全局广播总线** | EventBus | **明确不做的**，用信号直接连 |
| **事件队列** | events 数组 | 模拟核心往外吐结果用的数组，渲染读完要清 |

### 0.3 必须留英文的（Godot 自带，改不了也不该改）

| 类名 | 中文 |
|---|---|
| `Node2D` | 二维节点 |
| `Node` | 节点 |
| `CanvasLayer` | 画布层 |
| `Control` | 控件 |
| `TileMapLayer` | 瓦片层 |
| `MultiMeshInstance2D` | 多重网格实例（一次画完所有细胞方块） |
| `Resource` | 资源 |
| `Sprite2D` | 精灵 |
| `Camera2D` | 摄像机 |
| `PackedInt32Array` / `PackedByteArray` | 紧密整数数组 / 紧密字节数组 |
| `RefCounted` | 引用计数对象 |

### 0.4 文件路径一律照抄，不改

`scene/`、`script/`、`resource/`、`settings/` 下面沿用现有命名习惯
（`settings/controls/script/base_setting_control.gd` 那种小写下划线），
新加的文件按这个规矩放：

```
script/core/      纯逻辑，不挂节点
script/data/      Resource 子类
script/game/      关卡里的节点脚本
script/ui/        界面脚本
scene/grid/       世界里的子场景
scene/ui/         界面子场景
```

---

## 1. 三条边界规则（全篇的判断标准）

任何"这个类该放哪、该不该是全局单例"的问题，用这三条判断：

**边界一：只有"跨场景共享、且不带界面"的东西才配当全局单例。**

> 单例放**数据和行为**，不放**节点和界面**。
> 一个东西如果只在关卡活着的时候才有意义，它**不是**单例。

**边界二：纯逻辑不许碰场景树。**

> 模拟核心（§5）禁止引用任何 `Node`、`SceneTree`、`res://` 资源，
> 禁止读 `delta`。它只吃"地图数据 + 价目表"，吐事件。
> 这样它才能无头跑、能加速、能被 `test/` 直接调。

**边界三：渲染只读，输入只写。**

> 渲染器**永远不改**地图数据，只订阅信号 + 读数据。
> 输入**永远不直接画**，只往地图数据写字。
> 中间那层是编辑控制器，它是唯一同时认识输入和数据的地方。

---

## 2. 分层总览

```
┌─ 全局单例（开机一直在，跨场景）────────────────────────┐
│  路径 Path  控制台 Console  设置项 SettingItems          │
│  设置读写 SettingsIO  进度存档 Progress  定义表 Defs      │
└────────────────────────┬──────────────────────────────┘
                         │ 只读引用
┌────────────────────────▼──────────────────────────────┐
│  游戏场景 game.tscn（进一关实例化一次）                  │
│                                                        │
│  ┌─驱动─┐  ┌─编辑─┐   ┌─渲染─┐      ┌──界面──┐        │
│  │时钟  │  │编辑控│   │地形  │      │仪表    │        │
│  │倍速器│  │制器  │   │细胞  │      │底栏    │        │
│  └──┬───┘  │撤销栈│   │特效  │      │工坊    │        │
│     │      └──┬───┘   └──▲───┘      └───┬────┘        │
│     ▼         ▼          │              │             │
│  ┌───────────────────────┴──────────────┴──────────┐  │
│  │        核心层（纯逻辑，不挂节点）                 │  │
│  │   模拟核心  ⇄  地图数据  +  价目表（只读）        │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

**数据流永远是单向的**：

```
输入 → 编辑控制器 → 写地图数据 → 信号 → 渲染重画
                       ↓
                  模拟核心走一步 → 事件 → 渲染重画
```

---

## 3. 全局单例（只加 2 个）

| 单例 | 现有 / 新增 | 职责 | 禁止做什么 |
|---|---|---|---|
| `Path` 路径 | **现有** | 可执行文件目录，编辑器下回退到 `res://editor_path/` | — |
| `Console` 控制台 | **现有** | 游戏内控制台（F12）、日志、执行临时脚本 | — |
| `SettingItems` 设置项 | **现有** | 设置项内存字典 | — |
| `SettingsIO` 设置读写 | **现有** | 设置存成 JSON | — |
| `Progress` 进度存档 | **新增** | 研究点、已解锁细胞器与模式、已通关、成就标记；存盘 / 读盘 | **不碰地图数据、不碰模拟核心** |
| `Defs` 定义表 | **新增** | 开机扫 `resource/organelle/*.tres` 和 `resource/pattern/*.tres`，建 `id → 资源` 字典；提供按键名查 | **不做玩法计算**，只查表 |

### 为什么不多加

| 想加的 | 为什么不 |
|---|---|
| 模拟核心 | 它是**每关一份**的状态。做成单例就没法重开一关、没法单独测试 |
| 地图数据 | 同上，跟模拟核心同生命周期 |
| 倍速器 | 只在关卡里有意义，挂在时钟驱动底下当子节点 |
| 音乐音效 | 第一版没有音效，**现在不建空壳**。单例加太早，以后拆不掉 |
| 全局广播总线 | Godot 有信号，**不引第三方总线**。跨模块直接连信号（§12） |

### 单例之间的依赖方向（不许成环）

```
定义表 ← 进度存档        进度存档只读定义表的名字列表
路径   ← 设置读写        设置读写用 Path.exe_dir
控制台 ← （谁都不依赖它，它只被调用）
```

---

## 4. 场景清单

### 4.1 顶层场景（3 个，都用 `change_scene_to_file` 切换）

| 场景 | 现状 | 职责 |
|---|---|---|
| `scene/start.tscn` | 现有 | 主菜单：开始 / 设置 / 退出 |
| `scene/settings.tscn` | 现有 | 设置：复用 `settings/pages/*` |
| `scene/game.tscn` | 现有，**要大改** | 游戏唯一场景。**第零章和第一章所有关都用它**，靠关卡定义区分 |

> **不做关卡选择场景**：那是第一版之后的事，而且可以做进 `start.tscn` 的一个页签。

### 4.2 `game.tscn` 节点骨架（这是本文档的核心）

节点名是英文（场景树里就这么写）。括号里两种可能：**Godot 的节点类型**，
或者 **`instance`= 要实例化的子场景**。

```
Game (Node2D)
├── Core
│   ├── GridMap
│   └── Sim
├── SimDriver
│   └── TimeScale
├── EditController
│   └── UndoStack
├── World (Node2D)
│   ├── GridRoot
│   │   ├── TerrainLayer (TileMapLayer)
│   │   ├── CellLayer (MultiMeshInstance2D)
│   │   └── FxLayer
│   ├── GhostView
│   └── Camera2D
└── UI (CanvasLayer)
    ├── Hud
    ├── HintBar
    ├── Dock
    │   ├── BrushBar (HBoxContainer)
    │   ├── PatternBar (HBoxContainer)
    │   └── ActionBar (HBoxContainer)
    ├── WorkshopPanel
    │   ├── OrganelleTab
    │   └── PatternTab
    └── PauseMenu
```

每个节点是什么，看这两张表：

| 节点名 | 中文名 | 类型 | 脚本 |
|---|---|---|---|
| `Game` | 游戏根 | `Node2D` | `script/game.gd`，**只做装配** |
| `Core` | 核心层宿主 | `Node` | 无（不挂渲染） |
| `GridMap` | 地图数据 | `RefCounted` | `script/core/grid_map.gd` |
| `Sim` | 模拟核心 | `RefCounted` | `script/core/sim.gd` |
| `SimDriver` | 时钟驱动 | `Node` | `script/game/sim_driver.gd` |
| `TimeScale` | 倍速器 | `Node` | `script/game/time_scale.gd` |
| `EditController` | 编辑控制器 | `Node` | `script/game/edit_controller.gd` |
| `UndoStack` | 撤销栈 | `Node` | `script/game/undo_stack.gd` |
| `World` | 世界原点 | `Node2D` | 无 |
| `Camera2D` | 摄像机 | `Camera2D` | 现有 `script/camera.gd` |
| `UI` | 界面层 | `CanvasLayer` | 无 |

| 节点名 | 中文名 | `instance` 哪个子场景 |
|---|---|---|
| `GridRoot` | 网格总容器 | `scene/grid/grid_root.tscn` |
| `TerrainLayer` | 地形（区域底色 + 受体条） | 在 `grid_root.tscn` 里，不单独拆 |
| `CellLayer` | 细胞方块 | 在 `grid_root.tscn` 里，不单独拆 |
| `FxLayer` | 特效 | `scene/grid/cell_fx.tscn` |
| `GhostView` | 笔刷预览 | `scene/grid/ghost_view.tscn` |
| `Hud` | 顶部仪表 | `scene/ui/hud.tscn` |
| `HintBar` | 一句话提示 | `scene/ui/hint_bar.tscn` |
| `Dock` | 底栏容器 | `scene/ui/dock.tscn` |
| `BrushBar` | 画笔栏 | `scene/ui/brush_bar.tscn` |
| `PatternBar` | 模式栏 | `scene/ui/pattern_bar.tscn` |
| `ActionBar` | 动作栏 | `scene/ui/action_bar.tscn` |
| `WorkshopPanel` | 工坊侧栏 | `scene/ui/workshop_panel.tscn` |
| `OrganelleTab` | 细胞器页 | `scene/ui/workshop/organelle_tab.tscn` |
| `PatternTab` | 模式页 | `scene/ui/workshop/pattern_tab.tscn` |
| `PauseMenu` | 暂停菜单 | `scene/ui/pause_menu.tscn` |

> 地形和细胞不单独拆场景，是因为它们共用"待重画块"这一份数据，
> 拆开反而要来回传。它们由 `grid_root.gd` 统一驱动。

**`game.gd` 的职责只有装配**：

```gdscript
# script/game.gd —— 目标形态，第一版可以更简单
extends Node2D

@export var level: LevelDef            # 第一版直接指到 1-1 的 .tres

func _ready() -> void:
    # 1. 造核心层（纯逻辑，不挂节点，见 §5）
    var grid := GridMap.new(level.width, level.height)
    var sim := Sim.new(grid, level.build_economy(Defs))

    # 2. 把引用往下发，全部是"接线"，没有玩法
    $Core/GridMap.set_instance(grid)      # 或者直接持有引用，见 §5.1 注
    $Core/Sim.set_instance(sim)
    $SimDriver.setup(sim)
    $EditController.setup(grid, sim, $World/GridRoot)
    $World/GridRoot.setup(grid)
    $UI/Dock.setup(level)
```

### 4.3 全部子场景清单（细分到功能模块）

| # | 子场景 | 层 | 一句话职责 | 第一版 |
|---|---|---|---|---|
| 1 | `grid/grid_root.tscn` 网格总容器 | 渲染 | 世界坐标下所有网格内容的容器，转发 `setup()` | 要 |
| 2 | `grid/terrain_renderer.tscn` 地形 | 渲染 | 区域底色 + 受体条，按待重画块 `set_cell` | 要 |
| 3 | `grid/cell_renderer.tscn` 细胞 | 渲染 | 三样拼起来：本体层 + 状态叠加层（远景多重网格），近景贴图层。按待重画块更新（§7） | 要（先只做纯色本体） |
| 4 | `grid/cell_fx.tscn` 特效 | 渲染 | 凋亡 / 分裂的短特效，池化的小节点 | 占位 |
| 5 | `grid/ghost_view.tscn` 笔刷预览 | 渲染 | 悬停高亮 + 成本预览卡 | 要 |
| 6 | `ui/hud.tscn` 顶部仪表 | 界面 | 能量条与收支、模拟时间、倍速按钮、供给指示 | 要（供给指示以后） |
| 7 | `ui/hint_bar.tscn` 一句话提示 | 界面 | 底栏左侧"当前该做的那一件事" | 要 |
| 8 | `ui/dock.tscn` 底栏容器 | 界面 | 按关卡定义逐格解锁子栏 | 要 |
| 9 | `ui/brush_bar.tscn` 画笔栏 | 界面 | 三种笔刷 + 尺寸 + 撤销键 | 要（先只小笔刷） |
| 10 | `ui/pattern_bar.tscn` 模式栏 | 界面 | 模式选择（含「未定义」），灰显未解锁 | 要（先只有「空的」） |
| 11 | `ui/action_bar.tscn` 动作栏 | 界面 | 撤销 / 打开工坊 | 要 |
| 12 | `ui/workshop_panel.tscn` 工坊侧栏 | 界面 | 侧栏容器，两个页签 | 占位 |
| 13 | `ui/workshop/organelle_tab.tscn` 细胞器页 | 界面 | 细胞器列表（已解锁 / 需研究点 / 未发现） | 占位 |
| 14 | `ui/workshop/pattern_tab.tscn` 模式页 | 界面 | 模式列表 + 编辑器（名字 + 细胞器清单） | 占位 |
| 15 | `ui/pause_menu.tscn` 暂停菜单 | 界面 | 继续 / 重启本关 / 回主菜单 | 要 |

**"占位"= 第一版建空场景挂个脚本，不实现内容**，但节点名和 `setup()` 签名先定死。
这样第二版往里填不用改骨架。

---

## 5. 核心层（纯逻辑，不挂节点）

> **这一层是唯一的规则执行者。** 玩法数字、判定、事件全在这里。
> 设计文档改了玩法，只改这一层，渲染和界面不用动。

### 5.1 地图数据（`script/core/grid_map.gd`，继承 `RefCounted`）

**数据布局：分字段整排存，不用"一堆小对象"。** 理由：几千格的对象数组会卡，
而且分字段存天然支持"只遍历一个字段"。

```gdscript
class_name GridMap extends RefCounted

var width: int
var height: int

# ── 数据层（玩家画的）────────────────────────
var region_id: PackedInt32Array      # 每格：区域编号，0 = 无。设计文档 §4
var receptor: PackedInt32Array       # 每格：受体类型，0 = 无（只在外边界格有意义）

# ── 模拟层（长出来的）───────────────────────
var cell_slots: PackedByteArray      # 每格：0 = 无细胞，否则 = 模式 id
var organelle: PackedByteArray       # 每格 16 字节（4×4 内部小格），细胞器 id
                                     # 索引：格子序号 * 16 + i

# ── 待重画块（给渲染用）─────────────────────
const CHUNK := 32                    # 32×32 算一块
var chunk_dirty: PackedByteArray     # 每块 1 字节
var dirty_chunks: Array[Vector2i]    # 待重画的块列表

# ── 查询 ───────────────────────────────────
func idx(x: int, y: int) -> int
func in_bounds(x: int, y: int) -> bool
func has_cell(x: int, y: int) -> bool
func is_boundary(x: int, y: int) -> bool     # 四邻里有没有区域外 / 网格外

# ── 写入（只允许编辑控制器和模拟核心调）─────
func set_region(x, y, id: int) -> void       # 内部标脏
func set_receptor(x, y, t: int) -> void
func set_cell(x, y, pattern_id: int, organelles: PackedByteArray) -> void
func clear_cell(x, y) -> void

func snapshot_data_layer() -> Dictionary     # 给撤销栈：{region_id, receptor}
func restore_data_layer(d: Dictionary) -> void
```

**关键决定**

- **1 格 = 1 个细胞**（设计文档 §0 规则四）。`organelle` 那 16 字节是**渲染用**，
  模拟核心不许读它做判定 —— 这条写进 `sim.gd` 的文件头注释
- **受体标记和区域编号同生命周期**：清区域时一起清（设计文档 §10）
- **撤销只快照数据层**（区域编号 + 受体标记）。细胞是模拟产物，撤销后自然重算
  （设计文档 §0 规则一）。100×100 的地图一份快照约 80KB，50 步约 4MB，可以接受

### 5.2 模拟核心（`script/core/sim.gd`，继承 `RefCounted`）

```gdscript
class_name Sim extends RefCounted

var grid: GridMap
var energy: float                    # 唯一资源（设计文档 §8）
var sim_time: float                  # 模拟秒（暂停不涨，倍速只改推进速率）
var events: Array[Dictionary]        # 本步产生的事件，渲染读完要清

func _init(grid: GridMap, economy: Dictionary) -> void

func step(dt: float) -> void         # 固定 20Hz 调用，唯一入口
func drain_events() -> Array[Dictionary]

# ── 规则（全部对应设计文档某一节）────────────
func _step_metabolism(dt)            # 设计文档 §8 基础代谢：每个细胞每秒 -1
func _step_growth(dt)                # 设计文档 §8 五个条件 + §9 分裂
func _step_apoptosis(dt)             # 设计文档 §8 能量耗尽后凋亡
func _collect_production()           # 设计文档 §7 每个产能细胞器每秒 +3
func _supply_ok(region_id) -> bool    # 设计文档 §10 受体供给开关（第一版恒 true）
```

**价目表：模拟核心与 `res://` 之间的唯一接口**

```gdscript
{
    "split_cost": 30.0,          # 分裂一次
    "upkeep_per_cell": 1.0,      # 每个细胞每秒
    "organelle_yield": {"mitochondrion": 3.0},   # 每个该细胞器每秒
    "split_cooldown": 5.0,
    "apoptosis_grace": 0.0,
    "supply_default": true,      # 第一版恒 true
}
```

模拟核心**不认识**模式定义、不认识定义表、不认识 `.tres`。
时钟驱动把关卡定义翻译成这张价目表再传进来 —— 这是边界二的具体落地。

### 5.3 事件（模拟核心 → 渲染的唯一通道）

```gdscript
{"t": "cell_born",    "at": Vector2i, "pattern": int}
{"t": "cell_died",    "at": Vector2i}
{"t": "energy_low"}                      # 只在跨过阈值时发一次
{"t": "supply_lost",  "region": int}
{"t": "goal_progress","key": String, "value": float}
```

渲染读 `drain_events()` 放特效，界面读它更新提示。
**模拟核心不发信号**，因为它是引用计数对象，不是节点。

---

## 6. 时钟驱动与编辑控制

### 6.1 时钟驱动（`script/game/sim_driver.gd`，继承 `Node`）

**这是"确定性的一帧一步与渲染解耦"（设计文档 §18）的落地处。**

```gdscript
extends Node

const HZ := 20.0
const STEP := 1.0 / HZ

var _acc := 0.0
var _sim: Sim

func setup(sim: Sim) -> void

func _process(delta: float) -> void:
    _acc += delta * TimeScale.multiplier      # 暂停 = 0，1× / 2× / 4×
    var guard := 0
    while _acc >= STEP and guard < 8:         # 单帧最多补 8 步，防卡顿雪崩
        _sim.step(STEP)
        _acc -= STEP
        guard += 1
```

- **`_process` 只做累加，规则全在模拟核心里**
- 倍速只改 `multiplier`，**不改 `STEP`** —— 所以 4× 和 1× 结果完全一致（设计文档 §8）
- 暂停时 `multiplier = 0`，累加器不涨，模拟时间自然不动（设计文档 §17）

### 6.2 倍速器（`script/game/time_scale.gd`，继承 `Node`）

```gdscript
signal changed(multiplier: float)     # 0.0 / 1.0 / 2.0 / 4.0
var multiplier: float = 1.0
func set_paused(v: bool) -> void
func set_speed(v: float) -> void
```

**只有一个地方保存倍速。** 仪表只发请求，不自己记状态。

### 6.3 编辑控制器（`script/game/edit_controller.gd`，继承 `Node`）

**唯一同时认识"输入"和"数据"的地方**（边界三）。

```gdscript
extends Node

var _grid: GridMap
var _sim: Sim
var _tool: int = TOOL_BRUSH        # 笔刷 / 油漆桶 / 形状 / 受体
var _brush_size: int = 1           # 1 / 3 / 5
var _pattern: int = 0              # 当前模式（0 = 未定义）
var _dragging := false
var _stroke_touched := 0           # 本笔碰到多少格、多少格要转化（给成本预览）

func setup(grid, sim, grid_root) -> void
func _unhandled_input(e) -> void   # 左键按下 / 移动 / 松开，右键擦
func _apply_at(gp: Vector2i) -> void
func _commit_stroke() -> void      # 松手才结算（设计文档 §0 规则二）
func preview_cost(gp: Vector2i) -> Dictionary   # 给笔刷预览
```

- **松手才结算**，拖动过程中只更新预览
- 右键 = 擦除（设计文档 §6），所以这里处理两个鼠标键，不切工具
- **它自己不做规则判定**：能不能分裂、够不够能量，问模拟核心

### 6.4 撤销栈（`script/game/undo_stack.gd`，继承 `Node`）

```gdscript
const DEPTH := 50
func push(grid: GridMap) -> void          # 一笔开始前调一次
func undo(grid: GridMap) -> bool
func redo(grid: GridMap) -> bool
```

**只存数据层快照**（§5.1）。撤销后地图数据整体标脏，渲染重画、
模拟核心下一步按新图纸算，**不回溯细胞**。

---

## 7. 渲染层

> **这一节对应设计文档 §4 的"细胞有两种画法，看缩放决定"。**
> 玩法那边已经把视觉规则定死了：**远景色块、近景贴图、中间淡入淡出**。
> 这里说的是**怎么实现**。

### 7.1 细胞渲染：三样东西拼起来

远景（缩放 < 1.5×）和近景（≥ 1.5×）**同时存在**，只是透明度不同。
所以细胞渲染是一个容器，底下挂三样：

```
CellRender (Node2D)                       scene/grid/cell_renderer.tscn
├── BodyLayer    (MultiMeshInstance2D)    ① 细胞本体（远景用）
├── OverlayLayer (MultiMeshInstance2D)    ② 状态叠加（远景用，单独一层）
└── DetailHolder (Node2D)                 ③ 近景贴图，一格一个 Sprite2D
```

| 层 | 什么时候可见 | 画什么 | 实例数 |
|---|---|---|---|
| `BodyLayer` | 缩放 < 1.5× 时 alpha = 1，≥ 1.5× 时淡到 0 | 细胞本体，色块 + 描边 | **固定 = 地图总格数** |
| `OverlayLayer` | 只在有状态标记时亮 | "正在分裂""受伤""被选中"这类角标 | **固定 = 地图总格数** |
| `DetailHolder` | 缩放 ≥ 1.5× 时淡入 | 精细贴图、内部结构、动画 | 只放**视野内**的细胞 |

**三样共存，靠 alpha 切换。** 不销毁、不重建、不切场景树
—— 这就是"淡入淡出"能做得平滑的原因。

### 7.2 远景：整片一次画完（`BodyLayer` + `OverlayLayer`）

`MultiMeshInstance2D` 是 Godot 自带节点：一个节点带一份**实例表**，
每一行 = 一个实例的位置 + 颜色。几千个细胞只提交 **1 次绘制指令**。

**硬限制**：整张表**共用一张贴图、一份材质**，实例之间换不了图。
所以远景只能"色块 + 一点点偏移"，不能一格一张图。这个限制就是设计文档 §4
要分两档的根本原因，不是我们偷懒。

#### 每实例的外观：图集 + 自定义数据

Godot 4 的 `MultiMesh` 允许给每个实例塞 4 个浮点数（`use_custom_data = true`），
这 4 个数会送进着色器。用法：

```
一张图集（4×4 格，每格 64×64）
┌────┬────┬────┬────┐
│产能│防御│空  │边界│   ← 每个实例的"贴图"，其实是这张大图上的一个矩形
├────┼────┼────┼────┤
│ …  │ …  │ …  │ …  │
└────┴────┴────┴────┘
```

```gdscript
multimesh.set_instance_custom_data(i, Color(col, row, 0.0, 0.0))  # 图集第几行第几列
```

着色器按这两个数去图集里取对应矩形。**代价几乎为零**，还是 1 次绘制。

> 这一步**第一版不做**（第一版只有纯色方块），但**接口现在就留出来**：
> `grid_root` 只管调 `redraw_chunks`，"外观从哪来"是 `cell_renderer` 自己的事。

#### 状态叠加单独一层（`OverlayLayer`）

**这是"路线二"**，和上面的图集**不冲突，是叠加关系**：

- **图集管"这个细胞长什么样"** —— 属于模式，稳定不变，写在 `BodyLayer` 上
- **叠加层管"这个细胞现在怎么了"** —— 属于运行时状态，变化频繁，写在 `OverlayLayer` 上

分成两层的好处：

1. **一层脏了不用重画另一层**。细胞只是"开始分裂"，改 `OverlayLayer` 那一行就够了，
   `BodyLayer` 一动不用动
2. **状态标记可以叠在任何外观上**，不用为"产能型 + 正在分裂"这种组合单独做一张图
3. 大部分格子的叠加层是 `alpha = 0`，等于不显示，不额外花绘制

**两层必须用同一套格子索引**（`y * width + x`），这样一次 `redraw_chunks`
可以在同一个循环里同时写两层，不用遍历两遍。

```gdscript
func redraw_chunks(chunks: Array[Vector2i]) -> void:
    for c in chunks:
        for y in range(...):
            for x in range(...):
                var i := y * _map.width + x
                _write_body(i, x, y)       # 本体：模式 → 图集行列 + 颜色
                _write_overlay(i, x, y)    # 叠加：状态 → 亮或全透明
```

#### 一条铁律：不许运行时改实例数量

改 `instance_count` 会重新分配显存缓冲，几千实例下必掉帧。
做法是**一次分配满**（地图总格数），没有细胞的格子把颜色设成**全透明**来隐藏。

> 内存账：100×100 地图 = 一万实例。每个实例存位置 + 颜色 + 4 个自定义浮点，
> 一万个大约几百 KB，两层也就一两 MB。**完全可以接受，别为省这个去改实例数。**

### 7.3 近景：一格一个贴图（`DetailHolder`）

缩放 ≥ 1.5× 时，屏幕上只剩几十到几百个细胞，这时**一格一个 `Sprite2D` 完全不卡**，
想画多细都行：精细贴图、细胞膜、内部小格、动画。

**只放视野内的**：按摄像机可见矩形（外加一圈余量）建，不是全图。
余量是为了平移镜头时不用每帧重建。

**什么时候重建这份列表**：

- 缩放跨过 1.5× 阈值时
- 视野变化导致"需要显示的格数"变化超过 20% 时
- 当前显示的格子里有细胞出生 / 死亡时（只改那一个）

**不在每帧重建。** 近景下细胞数量本来就少，重建一次也就几百个节点。

#### 内部的 4×4 小格（设计文档 §4）

**归 `DetailHolder` 管**，不进入远景主路径。缩放 ≥ 1.5× 时每个细胞的贴图
本身就是按内部结构画的；鼠标悬停某个细胞时，再额外给那一个画一个小面板。

### 7.4 淡入淡出

```
缩放穿过 1.5×
  → 启动一个约 0.2 秒的插值（用 Tween 或自己存一个 progress）
  → 放大时：BodyLayer.modulate.a 1 → 0，DetailHolder.modulate.a 0 → 1
  → 缩小时：反过来
```

**三条硬要求**：

1. **两边位置必须严格对齐** —— 都用"格子中心 = `Vector2(x, y) * 64 + Vector2(32, 32)`"
   （设计文档 §18 世界坐标）。对不齐会看到细胞"跳"一下，比不做淡入还难看
2. **淡入淡出期间不许改实例数量**（§7.2 铁律）
3. **动画贴图只在近景跑**。远景要跑动画就得每帧重写整张实例表，
   那等于把省下来的性能全花回去 —— 所以**远景永远是静态色块**

### 7.5 其余渲染模块

| 模块 | 实现 | 更新时机 |
|---|---|---|
| 地形 | `TileMapLayer`，`set_cell` | 只重画"待重画块"里的块 |
| 特效 | 池化的 `Node2D` 小节点 | 收到 `cell_born` / `cell_died` 事件 |
| 笔刷预览 | `Control`（世界坐标）+ 成本预览卡 | 编辑控制器每次移动鼠标 |

**细胞渲染对外的接口只有两个**：

```gdscript
func setup(map: GridMap) -> void
func redraw_chunks(chunks: Array[Vector2i]) -> void
```

**第一版只实现 `BodyLayer` 的纯色版本**（`use_custom_data` 不开、图集不用、
`OverlayLayer` 留空、`DetailHolder` 不建）。第二版加图集，第三版加近景 + 淡入淡出。
**调用方（`grid_root.gd`）在三个阶段里一行都不用改。**

---

## 8. 界面层

| 模块 | 读什么 | 写什么 | 关键约束 |
|---|---|---|---|
| 顶部仪表 | 模拟核心的能量 / 模拟时间 / 倍速器 | 倍速按钮 → 倍速器 | **数字按关卡逐项解锁**（设计文档 §16 §17） |
| 一句话提示 | 关卡定义的提示列表 + 模拟核心事件 | 无 | 只显示"当前该做的那一件事"，不弹窗 |
| 底栏容器 | 关卡定义的解锁工具表 | 转发选择给编辑控制器 | 未解锁的**灰显 + 悬停"1-4 解锁"** |
| 画笔栏 | — | 笔刷 / 尺寸 → 编辑控制器 | 第一版只有小笔刷 |
| 模式栏 | 定义表 + 进度存档 | 模式 → 编辑控制器 | 含「未定义」；未解锁灰显 |
| 动作栏 | — | 撤销 → 撤销栈；工坊 → 工坊侧栏 | 撤销键**必须可见**（设计文档 §6） |
| 工坊侧栏 | 定义表 + 进度存档 | 保存模式 → 定义表 / 进度存档 | **侧栏，不是新场景**；暂停与运行中都能开 |
| 暂停菜单 | — | 继续 / 重启 / 回主菜单 | 重启 = 重新实例化 `game.tscn` |

**界面不认识地图数据。** 它只跟编辑控制器、倍速器、撤销栈、定义表、进度存档打交道。
这是边界三在界面侧的体现。

---

## 9. 信号约定（跨模块通信，不引全局广播总线）

**命名**：`过去式动词`，例如 `region_changed`（区域变了）、`cells_born`（长出新细胞了）、
`energy_changed`（能量变了）。信号名和代码标识符一样保留英文，一眼能看出是"已经发生的事"。

**连接方向**（谁连谁，单向）：

```
倍速器.changed（倍速变了）        → 时钟驱动
编辑控制器.stroke_done（画完了）  → 撤销栈.push、地形重画
编辑控制器.preview（预览请求）    → 笔刷预览
时钟驱动.stepped（走了一步）      → 细胞渲染、顶部仪表、一句话提示
撤销栈.restored（撤销完了）       → 地形全量重画、细胞全量重画
画笔栏.selected（选了笔刷）       → 编辑控制器
模式栏.selected（选了模式）       → 编辑控制器
底栏.undo_pressed（点了撤销）     → 撤销栈
动作栏.workshop_toggled（开了工坊）→ 工坊侧栏
```

**硬约束**：

- **不许双向连**：`A.x → B` 之后，`B` 不许再连回 `A.y` 形成环
- **不许跨层直接调用**：界面不许 `grid.set_region(...)`，只能找编辑控制器
- **模拟核心不发信号**（它是引用计数对象），只通过事件队列往外吐

---

## 10. 资源与数据定义

### 10.1 目录

```
resource/
├── picture/tile/          # 现有：bottom.png（地形格）
├── organelle/             # 新增：细胞器定义，一个一种
│   ├── mitochondrion.tres
│   ├── lysosome.tres
│   └── ...
├── pattern/               # 新增：模式定义（工坊产物 + 预设）
│   ├── blank.tres         # 「空的」
│   └── producer.tres      # 「产能型」
└── level/                 # 新增：关卡定义
    ├── chapter0.tres
    └── l1_01.tres
```

### 10.2 三个 `Resource` 子类

```gdscript
# script/data/organelle_def.gd
class_name OrganelleDef extends Resource
@export var id: StringName            # "mitochondrion"
@export var display_name: String      # "线粒体"（第一行大白话）
@export var latin_name: String        # 悬停第二行学名（设计文档 §12）
@export var energy_per_sec: float     # +3 / -1
@export var upkeep_per_sec: float
@export var unlock_cost: int          # 研究点
@export var icon: Texture2D

# script/data/pattern_def.gd
class_name PatternDef extends Resource
@export var id: StringName            # "producer"
@export var display_name: String
@export var color: Color              # 细胞方块颜色（设计文档 §18 纯色 + 描边）
@export var organelles: Array[StringName]   # 长度 ≤ 16（4×4 内部小格）

# script/data/level_def.gd
class_name LevelDef extends Resource
@export var chapter: int
@export var index: int
@export var width: int = 100
@export var height: int = 100
@export var goal: Dictionary          # {"type": "fill_ratio", "value": 0.6}
@export var presets: Array             # 预置：区域矩形 + 细胞 + 受体（设计文档 §16 预置表）
@export var unlocked_tools: Array[StringName]   # ["brush"] / ["brush", "paint"] ...
@export var show_energy_numbers: bool = false   # 第零章 false
@export var hints: Array[String]      # 顺序显示的一句话引导

func build_economy(defs) -> Dictionary   # 翻译成价目表（§5.2）
func apply_presets(grid: GridMap) -> void
```

- **字符串 id 贯穿全局**（设计文档 §18：为 mod 留路）。**不做 `ids.gd` 常量表** ——
  id 就是 `.tres` 的文件名，定义表扫目录建表，这样"加一个细胞器 = 加一个文件"
  才真的成立，不用再改第二个地方
- **关卡定义是"第零章和第一章所有关"的唯一差异来源**。`game.tscn` 只有一个，
  关卡之间的差别 100% 在 `.tres` 里，**代码里不写"如果这是第一章"这种判断**

---

## 11. 关键时序

### 11.1 画一笔

```
左键按下
  → 编辑控制器记下起点，撤销栈.push(地图数据)      ← 先存，后改
  → 拖动：每格调 set_region() / set_receptor()（内部标脏）
         同时更新笔刷预览的成本（只预览，不结算）
松手
  → 编辑控制器发出"这一笔画完了"
  → 地形按待重画块重画
  → 下一步，模拟核心按新区域算分裂（可能要几秒后才看出变化）
```

**注意**：`push` 在**按下时**，不是松手时 —— 这样一笔撤销回的是"动笔之前"。
松手才结算保证"画歪了还没花钱"（设计文档 §0 规则二）。

### 11.2 走一步

```
时钟驱动._process(delta)
  → 累加器 += delta × 倍速
  → while 累加器 >= 一步:
       模拟核心.step(一步)
         ├ 收产能        产能细胞器加能量
         ├ 算维持        每个细胞扣能量
         ├ 算生长        查五个条件，够就分裂（写地图数据 + 推事件）
         └ 算凋亡        能量见底后细胞死
  → 一帧结束前，渲染读事件放特效，仪表刷新数字
```

**模拟核心内部不许遍历全图**：维护"活细胞索引列表"和每个区域的细胞计数，
只遍历活细胞。全图只在加载时扫一次。

### 11.3 撤销

```
Ctrl+Z / 点撤销键
  → 撤销栈.undo(地图数据)
       ├ 只还原数据层
       └ 整体标脏
  → 地形全量重画
  → 细胞不动（它们是模拟产物），下一步按新图纸自然转化 / 凋亡
```

### 11.4 缩放穿过 1.5×（远景 ↔ 近景 淡入淡出）

```
摄像机 zoom 变化
  → 判断是否跨过阈值 1.5（**只看有没有穿过，不看具体值**）
      没穿过 → 什么都不做
      穿过了 → 细胞渲染启动一次约 0.2 秒的淡入淡出：
           放大：本体层 alpha 1→0，近景层 alpha 0→1
           缩小：反过来
  → 淡入淡出的**同时**，近景层按当前视野重建一次细胞列表（只放视野内的，见 §7.3）
```

**三条不许违反**（§7.4 已说明理由）：

1. 淡入淡出期间**不许改实例数量**
2. 两层的格子中心必须用同一个公式算，否则会"跳"
3. **只有近景跑动画**，远景永远是静态色块

> 这一条**第三版才做**。第一版和第二版里，摄像机可以自由缩放，
> 但细胞永远是色块 —— 没有淡入淡出，也不会有近景层。

---

## 12. 明确不做的（防止架构长胖）

| 不做的 | 原因 |
|---|---|
| 全局广播总线 | Godot 信号够用，总线会让调用关系看不见 |
| 模拟核心做成全局单例 | 每关一份状态，做成单例就没法重开、没法单独测 |
| 地图数据用 `Array[Cell]` 那种小对象堆 | 几千格会有性能坑，分字段整排存更稳 |
| 单独的"区域管理器" / "组织系统" | 设计文档 §20 明确砍掉：区域是数据，不是物件 |
| **给每个细胞建节点（远景）** | 几千个节点会掉帧。远景走多重网格，只有近景才一格一个（§7） |
| **运行时改多重网格的实例数量** | 会重新分配显存缓冲、必掉帧。一次分配满，空格子全透明隐藏（§7.2） |
| **远景跑动画贴图** | 要每帧重写整张实例表，等于把省下的性能全花回去。动画只在近景（§7.4） |
| **给远景的每个实例单独一份材质** | 多重网格做不到。要分外观就用图集 + 自定义数据（§7.2） |
| 关卡选择场景 | 可以做进主菜单的页签 |
| 音乐音效单例空壳 | 第一版没音效，现在建了以后拆不掉 |
| 实体组件系统（ECS）那类框架 | 这个规模不需要，反而增加阅读成本 |
| 存关卡中途状态 | 第一版只存设置和进度，不存网格 |

---

## 13. 落地顺序（每步都能看见东西）

**第一批：第一版（纯色方块，能玩）**

| 步 | 建什么 | 建完能验证什么 |
|---|---|---|
| 1 | `script/core/grid_map.gd` 地图数据 | 写个脚本能填格子、读格子（`test/` 里无头跑） |
| 2 | `script/core/sim.gd` 模拟核心 + `LevelDef.build_economy` | 无头跑 80 秒，看能量曲线对不对（设计文档 §19 验收） |
| 3 | `scene/grid/grid_root.tscn` + `terrain_renderer.tscn` | 屏幕上能看到区域底色 |
| 4 | `scene/grid/cell_renderer.tscn`（**只做纯色本体层**） | 能看到细胞一格一格长出来 |
| 5 | `script/game/sim_driver.gd` + `time_scale.gd` | 能按 1× / 2× / 4×，能暂停 |
| 6 | `script/game/edit_controller.gd` + `ghost_view.tscn` | 能画一笔，松手后长出来 |
| 7 | `script/game/undo_stack.gd` | 能撤销 |
| 8 | `scene/ui/hud.tscn` + `hint_bar.tscn` + `dock.tscn` | 第零章可玩 |
| 9 | `resource/level/chapter0.tres` + `l1_01.tres` | **第零章和 1-1 可玩** |
| 10 | `Defs` + `Progress` 单例 + 工坊侧栏骨架 | 1-2 的工坊有壳 |

**第 3 步之后每一步都能截图**，中间不留"写完一坨还看不见"的阶段。

**第二批：第二版（加图集，还是远景）**

| 步 | 建什么 | 建完能验证什么 |
|---|---|---|
| 11 | `resource/pattern/*.tres` 里加 `atlas_cell: Vector2i` | 模式能指定自己用图集哪一格 |
| 12 | `cell_renderer.gd` 开 `use_custom_data`，写图集偏移 | 几种细胞一眼能分出样子 |
| 13 | 加 `OverlayLayer`（同一套索引，第二个循环） | "正在分裂"这类状态能叠在任意外观上 |

**第三批：第三版（加近景 + 淡入淡出）**

| 步 | 建什么 | 建完能验证什么 |
|---|---|---|
| 14 | `cell_renderer.tscn` 加 `DetailHolder` 子节点 | 缩放 ≥1.5× 能看到精细贴图 |
| 15 | 缩放穿阈值触发淡入淡出（§11.4） | 切换时**位置不跳**，约 0.2 秒过渡 |
| 16 | 近景可见列表的重建条件（§7.3） | 平移镜头不卡、不闪烁 |

---

## 14. 审阅检查点（请重点看这几条）

1. **模拟核心不碰 `res://` 资源**，靠一张价目表通信（§5.2）—— 这个隔离划得对不对？
2. **地图数据用分字段整排存 + `Packed*Array`**（§5.1）—— 接受这个数据布局吗？
3. **细胞渲染分三批做**（§7、§13）：第一版纯色方块 → 第二版远景图集 + 状态叠加层
   → 第三版近景贴图 + 淡入淡出。**三个阶段里 `grid_root.gd` 一行都不用改**
4. **远景和近景靠 alpha 共存、不销毁重建**（§7.1、§7.4）—— 这是淡入淡出做得平滑的前提
5. **只加进度存档和定义表两个单例**（§3）—— 够不够，还是漏了什么？
6. **关卡定义承担全部关卡差异，`game.tscn` 只有一份**（§10.2）—— 第零章和第一章共用它，接受吗？
7. **撤销只回数据层、不回细胞**（§11.3）—— 语义是否清楚？
8. **15 个子场景**（§4.3）—— 有没有该合起来或者该拆开的？
