extends "res://theme_d/level6/cube_world.gd"

## 第六关《禅面造阶》的立方体控制器（自由翻面 + 三段建造）。
##
## 核心规则：
##  - 翻面方向不限：推哪一面都能翻，其他面翻了只改重力，不推进阶段。
##  - B 成底面 → 青球亮起；L 成底面 → 出口直接打开。
##  - 两颗球在右边墙 R：金球 R(1,1) 直接 +3 块；青球 R(2,0) 在 B 成底面后
##    升到 (2.5,3.5,2.5)，+3 块。吃球只补积木，不再锁翻面方向。
##  - 自由建造：鼠标移到主角周围四格，块按重力落到支撑上；点一下放。
##
## 标准路线（不唯一）：
##  1. 金球 +3；第一段在 B 墙脚摆 3 块，翻 B 后叠成 2 米塔 + 1 米台阶。
##  2. 青球 +3；第二段在 L 墙脚放 L(0,1) 1 米基座 + L(0,2) 1 米踏板，
##     再把 R(5,1) 的块放到 L(0,1) 上，翻 L 后叠成 2 米塔。
##  3. 固定软糖 B(3,1) 两翻后是 3 米塔顶；最后一块备用，可当踏板或调整落点。
##     踩第一段的 1→2 米台，跳到 3 米软糖塔顶，再跳进 5.5 米出口。
##
## 固定布局：出口 E=D(5,0)（5.5 米），禅图固定种子；固定软糖作为障碍/落脚点。
##
## 美术：白色软糖工作室（studio_*.gdshader / gummy_block.gdshader）；
## 白墙 + 半透明高饱和软糖，出口门洋红/青两态。

signal flip_blocked(reason: String)
signal build_refused(reason: String)
signal exit_activated
signal build_state_changed
signal orb_collected(index: int, blocks: int, next_face: String)
signal player_crushed

const GRID_N := 6
const BUILD_REACH := 1.35

const BLOCK_SHADER := preload("res://theme_d/level6/gummy_block.gdshader")

## 软糖工作室调色板：白瓷底 + 高饱和半透明叠层。
const GUMMY_WHITE := Color(0.985, 0.982, 0.972)
const GUMMY_MAGENTA := Color(1.0, 0.0, 0.41)
const GUMMY_RED := Color(0.84, 0.02, 0.10)
const GUMMY_ORANGE := Color(0.94, 0.35, 0.02)
const GUMMY_YELLOW := Color(1.0, 0.83, 0.0)
const GUMMY_GREEN := Color(0.10, 0.72, 0.32)
const GUMMY_CYAN := Color(0.13, 0.83, 0.93)
const GUMMY_BLUE := Color(0.11, 0.31, 0.85)
const GUMMY_DEEP_BLUE := Color(0.025, 0.075, 0.46)
const GUMMY_LILAC := Color(0.78, 0.66, 1.0)
const GUMMY_PURPLE := Color(0.49, 0.23, 0.93)
const GUMMY_INK := Color(0.18, 0.18, 0.20)

## 旧 De Stijl 常量保留给尚未清理的拱心石死代码引用；新物块不再使用。
const DE_STIJL_CREAM := Color(0.95, 0.93, 0.88)
const DE_STIJL_RED := Color(0.84, 0.16, 0.16)
const DE_STIJL_BLUE := Color(0.11, 0.30, 0.54)
const DE_STIJL_YELLOW := Color(0.95, 0.72, 0.02)
const DE_STIJL_INK := Color(0.067, 0.067, 0.067)

## 禅图方块：每颗从高饱和软糖色里取一个，颜色丰富但仍比主块更轻。
const MAZE_PALETTE := [
	Color(1.00, 0.12, 0.46),
	Color(1.00, 0.48, 0.66),
	Color(0.08, 0.68, 0.30),
	Color(0.52, 0.82, 0.20),
	Color(0.82, 0.05, 0.12),
	Color(0.95, 0.36, 0.05),
	Color(0.08, 0.28, 0.90),
	Color(0.36, 0.62, 1.00),
	Color(0.48, 0.16, 0.92),
	Color(0.78, 0.55, 1.00),
	Color(0.05, 0.70, 0.68),
]
const MAZE_GRID_COLOR := Color(0.52, 0.60, 0.65)

## 固定软糖的 tone 对应。
const GUMMY_BY_TONE := {
	"strawberry": GUMMY_MAGENTA,
	"lemon": GUMMY_YELLOW,
	"grape": GUMMY_PURPLE,
	"lime": GUMMY_GREEN,
	"blueberry": GUMMY_BLUE,
	"deep_blue": GUMMY_DEEP_BLUE,
	"cherry": GUMMY_RED,
	"pedestal": GUMMY_WHITE,
}

## B(3,1)：最后一块“拱心石”的格。两翻后世界中心 (2.5,2.5,1.5)，顶面 3 米。
const UPPER_LILAC_CELL := Vector3i(-3, 11, -5)
const KEYSTONE_CELL := Vector3i(-1, 3, -5)
## B(4,1)：固定软糖基座。两翻后世界中心 (2.5,1.5,1.5)，顶面 2 米。
const PEDESTAL_CELL := Vector3i(-3, 3, -5)
## R(5,1)：旧第二段的落块格，现在是保留位；提前占掉会破坏 3 米塔顶。
const RESERVED_FALL_CELL := Vector3i(5, 3, -5)

## 每颗球补充的积木数。金球 3 块，青球 4 块。
const ORB_BLOCKS := 3
const ORB_BLOCKS_SECOND := 3

## 固定展示关：禅图方块只生成一次。换这个数字会换一整套禅图。
const FIXED_MAZE_SEED := 20261118

## 点选发光格用的独立碰撞层，玩家不会撞到它。
const GHOST_LAYER := 1 << 7

## 两次目标底面的提示色：柠檬/蓝莓糖果。
const FLIP_COLOR_A1 := Color(1.0, 0.82, 0.28)
const FLIP_COLOR_A2 := Color(0.38, 0.72, 1.0)

## 出口门：洋红关 / 青开（待命黄只留给死代码编译用）。
const EXIT_DOOR_COLOR_CLOSED := GUMMY_MAGENTA
const EXIT_DOOR_COLOR_ARMED := GUMMY_YELLOW
const EXIT_DOOR_COLOR_OPEN := GUMMY_CYAN

## 固定软糖块：不属于玩家积木，也不会被收回/重力移动。
## 它们是关卡里的大颗软糖，既可能是障碍，也可能成为落脚点；
## 位置避开已验证的通关格。cell 是双倍坐标（格心 0.5，奇数值）。
const FIXED_BLOCKS := [
	# 初始 D 地面正前方两块软糖：可以从它们跳上右边墙拿金球；
	# 两翻后到 (-2.5,4.5/5.5,2.5)，远离出口列。
	{"cell": Vector3i(3, 1, 5), "tone": "lime"},
	{"cell": Vector3i(5, 1, 5), "tone": "lemon"},
	# D 右前方两颗：第一翻后正好叠成青球脚下的 2 米软糖台，
	# 可以从第一段 2 米塔直接踏上去吃青球（助力）。
	{"cell": Vector3i(5, 1, -1), "tone": "blueberry"},
	{"cell": Vector3i(5, 1, -3), "tone": "cherry"},
	# B 面 3 米侧软糖 + 它下面的 1/2 米两颗：故意做成一条
	# 1→2→3 米的“第二条楼梯”，但 3 米顶离出口还有 2.5 米，跳不上去。
	# 这是给玩家的主要误导路线，不是解法。
	{"cell": Vector3i(-5, 5, -5), "tone": "grape"},
	{"cell": Vector3i(-3, 5, -5), "tone": "grape"},
	{"cell": Vector3i(-1, 5, -5), "tone": "grape"},
	# 第一段固定基座：B(5,0) 的 1 米软糖。玩家把 3 块接在它上面，
	# 两翻后它就在 (2.5,0.5,2.5)，成为 1→2→3 米台阶的第一级。
	{"cell": Vector3i(-5, 1, -5), "tone": "lime"},
	# 第二段建造行里的那颗软糖：B 成底面时在 z=1.5 的行里，
	# 两翻后正好落在第二段 3 米塔的塔顶 (2.5,2.5,1.5)。
	# 它替掉了玩家原本要放的第三块：玩家要站到它左边，
	# 在自己的两块上面把它顶成 3 米塔顶（省下 1 块备用）。
	{"cell": Vector3i(-1, 3, -5), "tone": "strawberry"},
	# 最终左面：两颗淡紫色块（下方那颗）的前面一格（朝房间内）。
	# 初始在 (3,11,3)，两翻后落在 (-1.5,4.5,-2.5)，正对下方淡紫色块 (-2.5,4.5,-2.5)。
	{"cell": Vector3i(3, 11, 3), "tone": "blueberry"},
	# 第二翻后 L 面成为底面时，位于那颗淡紫色块的正上方。
	# 初始在 B 面内侧 (-3,9,-5)，第一翻后为 (-1.5,0.5,-1.5)，
	# 第二翻后应比淡紫色块高 1 米。
	{"cell": Vector3i(-3, 9, -5), "tone": "deep_blue"},
	# 创造者模式里最终保留的 4 块设计，已固化为关卡固定软糖。
	{"cell": Vector3i(-5, 9, -3), "tone": "blueberry"},
	{"cell": Vector3i(-3, 9, 5), "tone": "lemon"},
	{"cell": Vector3i(-3, 11, 1), "tone": "lemon"},
	{"cell": Vector3i(1, 11, 5), "tone": "cherry"},
]

## 禅图方块铺放密度。
const MAZE_DENSITY := 0.45

const SIDE_FACES := ["F", "B", "L", "R"]
const OPPOSITE_FACE := {
	"F": "B",
	"B": "F",
	"L": "R",
	"R": "L",
	"U": "D",
	"D": "U",
}

## 8 组经过搜索验证的两翻布局。
## a1/a2 是两次翻面；e/ei/ej 是最终出口格。
## s2_* 是第二翻前在 A2 / 对面 O2 墙脚要搭的三块。
const MULTI_LAYOUTS := [
	{"a1": "F", "a2": "L", "e": "F", "ei": 4, "ej": 0, "s2_step_i": 5, "s2_step_j": 2, "s2_base_i": 5, "s2_base_j": 1, "s2_fall_i": 0, "s2_fall_j": 1},
	{"a1": "F", "a2": "R", "e": "F", "ei": 1, "ej": 0, "s2_step_i": 0, "s2_step_j": 2, "s2_base_i": 0, "s2_base_j": 1, "s2_fall_i": 5, "s2_fall_j": 1},
	{"a1": "B", "a2": "L", "e": "B", "ei": 1, "ej": 0, "s2_step_i": 0, "s2_step_j": 2, "s2_base_i": 0, "s2_base_j": 1, "s2_fall_i": 5, "s2_fall_j": 1},
	{"a1": "B", "a2": "R", "e": "B", "ei": 4, "ej": 0, "s2_step_i": 5, "s2_step_j": 2, "s2_base_i": 5, "s2_base_j": 1, "s2_fall_i": 0, "s2_fall_j": 1},
	{"a1": "L", "a2": "F", "e": "L", "ei": 1, "ej": 0, "s2_step_i": 0, "s2_step_j": 2, "s2_base_i": 0, "s2_base_j": 1, "s2_fall_i": 5, "s2_fall_j": 1},
	{"a1": "L", "a2": "B", "e": "L", "ei": 4, "ej": 0, "s2_step_i": 5, "s2_step_j": 2, "s2_base_i": 5, "s2_base_j": 1, "s2_fall_i": 0, "s2_fall_j": 1},
	{"a1": "R", "a2": "F", "e": "R", "ei": 4, "ej": 0, "s2_step_i": 5, "s2_step_j": 2, "s2_base_i": 5, "s2_base_j": 1, "s2_fall_i": 0, "s2_fall_j": 1},
	{"a1": "R", "a2": "B", "e": "R", "ei": 1, "ej": 0, "s2_step_i": 0, "s2_step_j": 2, "s2_base_i": 0, "s2_base_j": 1, "s2_fall_i": 5, "s2_fall_j": 1},
]

const FACE_DEFS := {
	"U": {
		"origin": Vector3(0.0, 5.5, 0.0),
		"out": Vector3(0.0, 1.0, 0.0),
		"u": Vector3(1.0, 0.0, 0.0),
		"v": Vector3(0.0, 0.0, -1.0),
	},
	"D": {
		"origin": Vector3(0.0, 0.5, 0.0),
		"out": Vector3(0.0, -1.0, 0.0),
		"u": Vector3(1.0, 0.0, 0.0),
		"v": Vector3(0.0, 0.0, 1.0),
	},
	"F": {
		"origin": Vector3(0.0, 3.0, 2.5),
		"out": Vector3(0.0, 0.0, 1.0),
		"u": Vector3(1.0, 0.0, 0.0),
		"v": Vector3(0.0, 1.0, 0.0),
	},
	"B": {
		"origin": Vector3(0.0, 3.0, -2.5),
		"out": Vector3(0.0, 0.0, -1.0),
		"u": Vector3(-1.0, 0.0, 0.0),
		"v": Vector3(0.0, 1.0, 0.0),
	},
	"L": {
		"origin": Vector3(-2.5, 3.0, 0.0),
		"out": Vector3(-1.0, 0.0, 0.0),
		"u": Vector3(0.0, 0.0, 1.0),
		"v": Vector3(0.0, 1.0, 0.0),
	},
	"R": {
		"origin": Vector3(2.5, 3.0, 0.0),
		"out": Vector3(1.0, 0.0, 0.0),
		"u": Vector3(0.0, 0.0, -1.0),
		"v": Vector3(0.0, 1.0, 0.0),
	},
}

## 调试用：强制指定两翻的面，留空则随机。
@export var debug_force_flip_face := ""
@export var debug_force_flip_face2 := ""
@export var debug_force_base_i := -1
@export var debug_force_exit_face := ""

## 当前布局。
var _a1 := "F"
var _a2 := "L"
var _base_i := 3
var _step_i := 4
var _fall1_face := "B"
var _fall1_i := 2
var _s2_step_face := "L"
var _s2_step_i := 5
var _s2_step_j := 2
var _s2_base_face := "L"
var _s2_base_i := 5
var _s2_base_j := 1
var _s2_fall_face := "R"
var _s2_fall_i := 0
var _s2_fall_j := 1
var _exit_face := "F"
var _exit_i := 4
var _exit_j := 0

## 第二翻后，第一段三块压成的塔在 A2 地面上的格。
var _tower_face := "L"
var _tower_i := 0
var _tower_j := 0

## 布景/状态。
var build_charges: int = 0
var _placed: Array[Dictionary] = []
var _occupied: Dictionary = {}
var _block_serial: int = 0

var _maze_cells: Dictionary = {}
var _maze_face_cells: Dictionary = {}
var _maze_serial: int = 0
var _maze_protected: Dictionary = {}

var _stage := 0  # 0=起始地面，1=第一目标面后，2=第二目标面后
var _allowed_flip_face := "F"  # 当前阶段的目标底面（只做提示，不限制翻面方向）
var _orbs_collected := 0
var _orbs: Array[Dictionary] = []
var _orbs_root: Node3D

var _exit_active := false
var _flip_count := 0
var _gravity_busy := false

## 翻面下落：冻结玩家，直到所有落块合模、碰撞恢复。
var _settle_hold := false
## 当前正在下落的玩家积木；只在这些块移动期间做砸中判定。
var _crush_watch: Array[Node] = []
var _crush_triggered := false

var _pan_capture: Area3D
var _pan_vortex: Node3D
var _pan_beam: Node3D
var _pan_light: OmniLight3D

var _rng := RandomNumberGenerator.new()

## 3D 建造提示：翻面边框 + 发光格位。
var _hint_root: Node3D
var _flip_frame: Node3D
var _flip_frame_mat: StandardMaterial3D
var _hint_time := 0.0

## 自由建造：主角周围四格的落点提示，鼠标悬停时闪烁。
var _place_markers: Array[Dictionary] = []
var _hovered_marker: StaticBody3D
var _place_refresh := 0.0
var _gummy_mesh: ArrayMesh

## 出口门（初始底面 D 上的 1 米门框）。
## 三态：关（红）/ 待命（黄，L 已翻成底面）/ 开（蓝，拱心石已落位）。
var _exit_door_open := false
var _exit_armed := false
var _keystone_placed := false
var _exit_door_frame: Node3D
var _exit_door_mat: StandardMaterial3D

## 拱心石提示：3D 幽灵块 + 连到出口的构成线 + 落位爆发。
var _keystone_ghost: Node3D
var _keystone_link: MeshInstance3D
var _keystone_fx: Array[Node3D] = []


func _ready() -> void:
	# 透明膜外壳：六面全显示，不再按镜头裁切，否则立方体会变成开口盒子。
	wall_visible_dot = 0.2
	# 固定展示关：布局写死，禅图用固定种子，保证每次进来一模一样。
	_rng.seed = FIXED_MAZE_SEED
	_apply_fixed_layout()
	_build_protected_cells()
	_spawn_maze_blocks()
	_spawn_fixed_blocks()

	# 先让出口休眠，再交给父类做裁切初始化。
	_setup_exit_pan()
	_apply_exit_pan_transform()
	super()
	_spawn_floor_grid()
	_spawn_orbs()
	_spawn_build_hints()
	_spawn_exit_door()
	flip_started.connect(_on_flip_started)
	flip_finished.connect(_on_flip_finished)
	build_state_changed.emit()


func _process(delta: float) -> void:
	# 翻面落块期间角色不能被物理驱动，否则会穿过正在下落的积木。
	if _settle_hold:
		_keep_player_frozen()
	if _gravity_busy and not _crush_triggered and not _crush_watch.is_empty():
		if _check_crush():
			return
	_hint_time += delta
	if _flip_frame_mat != null:
		# 目标底面框一直呼吸：它不是“只能翻的面”，而是“翻成底面会触发下一步”的面。
		var speed := 3.2
		var base := 1.6
		var amp := 0.8
		var pulse := 0.5 + 0.5 * sin(_hint_time * speed)
		_flip_frame_mat.emission_energy_multiplier = base + amp * pulse
		# 兼容渲染器下 emission 不一定发光，再让透明度一起呼吸，保证看得出“一闪一闪”。
		var c := _flip_frame_mat.albedo_color
		c.a = 0.45 + 0.4 * pulse
		_flip_frame_mat.albedo_color = c
	if _exit_door_mat != null:
		var active := _exit_door_open
		var armed := _exit_armed and not active
		var door_speed := 4.6 if active else (3.2 if armed else 1.8)
		var door_pulse := 0.5 + 0.5 * sin(_hint_time * door_speed)
		var base_energy := 1.7 if active else (1.2 if armed else 0.8)
		var amp := 0.9 if active else (0.5 if armed else 0.25)
		_exit_door_mat.emission_energy_multiplier = base_energy + amp * door_pulse
		var alpha_base := 0.55 if active else (0.45 if armed else 0.3)
		var alpha_amp := 0.45 if active else (0.3 if armed else 0.18)
		var d := _exit_door_mat.albedo_color
		d.a = alpha_base + alpha_amp * door_pulse
		_exit_door_mat.albedo_color = d
	if _keystone_ghost != null and is_instance_valid(_keystone_ghost) and _keystone_ghost.visible:
		var gp := 0.5 + 0.5 * sin(_hint_time * 2.6)
		_keystone_ghost.scale = Vector3.ONE * (0.96 + 0.06 * gp)
		_keystone_ghost.rotation.y = _hint_time * 0.35
	if _keystone_link != null and is_instance_valid(_keystone_link):
		var lm := _keystone_link.material_override as StandardMaterial3D
		if lm != null:
			lm.emission_energy_multiplier = 1.1 + 0.7 * (0.5 + 0.5 * sin(_hint_time * 3.4))

	_place_refresh += delta
	if _place_refresh >= 0.1:
		_place_refresh = 0.0
		_refresh_place_markers()
	_update_place_hover()
	_pulse_place_markers()

	# 金球一开始是包着的；玩家走近时糖纸才会打开。
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player != null:
		for entry in _orbs:
			if (
				not bool(entry.get("wrapped", true))
				or bool(entry.get("unwrapping", false))
				or bool(entry.get("collected", false))
				or not bool(entry.get("active", false))
			):
				continue
			var node := entry.get("node") as Node3D
			if node != null and node.global_position.distance_to(player.global_position) < 1.9:
				_open_wrapper(int(entry.get("index", -1)))


## 禅图方块不参与父类的“按最近墙面裁切”绑定：
## 棱上的方块会被同时绑到两面（包括被裁掉的那一面），
## 结果在开口处浮着几块方块。这里改成按“生成时所在的面”单独控制。
func _bind_props_to_walls() -> void:
	super()
	var kept: Array[Dictionary] = []
	for entry in _wall_props:
		var prop = entry.get("prop")
		if prop is Node and (prop as Node).is_in_group("level6_maze"):
			continue
		kept.append(entry)
	_wall_props = kept


func update_cutaway_visibility() -> void:
	super()
	var hidden := get_hidden_faces()
	for node in get_tree().get_nodes_in_group("level6_maze"):
		var block := node as Node3D
		if block == null:
			continue
		var face := str(block.get_meta("maze_face", ""))
		block.visible = not hidden.has(face)


# ---------------------------------------------------------------- 固定布局

## 固定展示关的骨架：
##   A1=B（开局视角左边那面）→ 翻成第一层地面；
##   A2=L（右边球所在面 R 的对面）→ 第二次翻面，玩家要 Q/E 转过来；
##   出口 E=D(5,0)（5.5 米），在初始底面上、R/B 角落。
##   金球 R(1,1) 解锁第一翻；青球 R(2,0) 第一翻后升到塔右上方、
##   开门并解锁第二翻。两颗球都在右边墙上、开局可见。
##
## 建造与最后一块：
##   第一段在 B 墙脚摆 3 块，第一翻后叠成 (2.5,2.5) 的 2 米塔 + 1 米台阶。
##   第二段在 L 墙脚放 L(0,1) 1 米基座，再把 R(5,1) 的块放到软糖顶；
##   固定软糖 B(3,1) 两翻后是 3 米塔顶，R(5,1) 叠上去成 4 米起跳台。
##   最后一块备用，可当踏板或调整落点；第二翻完成即打开出口。
func _apply_fixed_layout() -> void:
	_a1 = "B"
	_a2 = "L"
	# B(3,0) 已改成固定 1 米基座；玩家接 B(2,0)=2 米、B(1,0)=3 米。
	_base_i = 2
	_step_i = 1
	_fall1_face = "F"
	_fall1_i = 2
	# 第二段 2 米垫块：接在主软糖下面，和 L(0,1) 的 1 米块咬合。
	_s2_step_face = "B"
	_s2_step_i = 4
	_s2_step_j = 1
	_s2_base_face = "L"
	_s2_base_i = 0
	_s2_base_j = 1
	_s2_fall_face = "R"
	_s2_fall_i = 5
	_s2_fall_j = 1
	_exit_face = "D"
	_exit_i = 5
	_exit_j = 0
	_tower_face = "L"
	_tower_i = 0
	_tower_j = 0
	_allowed_flip_face = _a1


# ---------------------------------------------------------------- 随机布局（保留作设计工具，关卡不再调用）

func _choose_layout() -> void:
	var candidates: Array[Dictionary] = []
	for entry in MULTI_LAYOUTS:
		if debug_force_flip_face != "" and str(entry["a1"]) != debug_force_flip_face:
			continue
		if debug_force_flip_face2 != "" and str(entry["a2"]) != debug_force_flip_face2:
			continue
		if debug_force_exit_face != "" and str(entry["e"]) != debug_force_exit_face:
			continue
		var solved := _solve_from_template(entry)
		if not solved.is_empty():
			candidates.append(solved)

	if candidates.is_empty():
		push_error("Level6: 找不到可行的两翻布局，回退到固定解。")
		candidates.append(_solve_from_template(MULTI_LAYOUTS[0]))

	var pick: Dictionary = candidates[_rng.randi_range(0, candidates.size() - 1)]
	_a1 = str(pick["a1"])
	_a2 = str(pick["a2"])
	_base_i = int(pick["base_i"])
	_step_i = int(pick["step_i"])
	_fall1_face = str(pick["fall1_face"])
	_fall1_i = int(pick["fall1_i"])
	_s2_step_face = str(pick["s2_step_face"])
	_s2_step_i = int(pick["s2_step_i"])
	_s2_step_j = int(pick["s2_step_j"])
	_s2_base_face = str(pick["s2_base_face"])
	_s2_base_i = int(pick["s2_base_i"])
	_s2_base_j = int(pick["s2_base_j"])
	_s2_fall_face = str(pick["s2_fall_face"])
	_s2_fall_i = int(pick["s2_fall_i"])
	_s2_fall_j = int(pick["s2_fall_j"])
	_exit_face = str(pick["exit_face"])
	_exit_i = int(pick["exit_i"])
	_exit_j = int(pick["exit_j"])
	_tower_face = str(pick["tower_face"])
	_tower_i = int(pick["tower_i"])
	_tower_j = int(pick["tower_j"])
	_allowed_flip_face = _a1


func _solve_from_template(template: Dictionary) -> Dictionary:
	var a1 := str(template["a1"])
	var a2 := str(template["a2"])
	if a1 == a2 or a2 == str(OPPOSITE_FACE[a1]):
		return {}

	var q1 := Quaternion(FACE_DEFS[a1]["out"] as Vector3, Vector3.DOWN)
	var out2_world := (q1 * (FACE_DEFS[a2]["out"] as Vector3)).normalized()
	if absf(out2_world.y) > 0.9:
		return {}
	var qf2 := Quaternion(out2_world, Vector3.DOWN)
	var q2 := qf2 * q1

	var exit_face := str(template["e"])
	var ei := int(template["ei"])
	var ej := int(template["ej"])
	var exit_cell_local := cell_local_position(exit_face, ei, ej)
	var exit_cell_key := _cell_key(_local_to_cell(exit_cell_local))

	# 出口锅开局就摆在 A1 墙脚，占着那一格。第一段的 base/step 不能
	# 放到锅所在的格子上，否则 place_block 会拒绝，玩家会以为是 bug。
	var base_options: Array[int] = []
	if debug_force_base_i >= 0:
		base_options.append(debug_force_base_i)
	else:
		for bi in range(GRID_N):
			base_options.append(bi)
	for i in range(base_options.size() - 1, 0, -1):
		var swap_i := _rng.randi_range(0, i)
		var tmp := base_options[i]
		base_options[i] = base_options[swap_i]
		base_options[swap_i] = tmp

	# 随机选的 base 可能恰好让 step 落在出口锅那格（或无邻格），
	# 这时换一根 base 重试，返回第一个完整可行的解。
	for bi in base_options:
		if bi < 0 or bi >= GRID_N:
			continue
		if cell_key(a1, bi, 0) == exit_cell_key:
			continue
		var solved := _solve_with_base(
			template, a1, a2, q1, qf2, q2, exit_cell_local, exit_cell_key, bi
		)
		if not solved.is_empty():
			return solved
	return {}


func _solve_with_base(
	template: Dictionary,
	a1: String,
	a2: String,
	q1: Quaternion,
	qf2: Quaternion,
	q2: Quaternion,
	exit_cell_local: Vector3,
	exit_cell_key: String,
	base_i: int
) -> Dictionary:
	var exit_face := str(template["e"])
	var ei := int(template["ei"])
	var ej := int(template["ej"])
	var base_local := cell_local_position(a1, base_i, 0)
	var base_after := _rotate_point(q1, _center(), base_local)
	if absf(base_after.y - 0.5) > 0.02:
		return {}

	# 第一翻的 fall：在 A1 的对面 O1 最底排，翻后正好落进 base 列。
	var o1: String = OPPOSITE_FACE[a1]
	var fall1_i := -1
	for fi in range(GRID_N):
		var fw := _rotate_point(q1, _center(), cell_local_position(o1, fi, 0))
		if (
			absf(fw.x - base_after.x) <= 0.01
			and absf(fw.z - base_after.z) <= 0.01
			and absf(fw.y - 5.5) <= 0.01
		):
			fall1_i = fi
			break
	if fall1_i < 0:
		return {}

	# 第一翻的 step：base 旁边，翻后仍在地面。
	var step_candidates: Array[int] = []
	for ds in [-1, 1]:
		var si: int = base_i + ds
		if si < 0 or si >= GRID_N:
			continue
		if cell_key(a1, si, 0) == exit_cell_key:
			continue
		var sw := _rotate_point(q1, _center(), cell_local_position(a1, si, 0))
		if (
			absf(sw.y - 0.5) <= 0.02
			and absf(absf(sw.x - base_after.x) + absf(sw.z - base_after.z) - 1.0) <= 0.02
		):
			step_candidates.append(si)
	if step_candidates.is_empty():
		return {}
	var step_i: int = step_candidates[_rng.randi_range(0, step_candidates.size() - 1)]

	# 第二翻后，第一段三块所在的塔列。
	var tower_after := _rotate_point(qf2, _center(), base_after)
	var tower_cell := _find_face_cell_after(q2, a2, tower_after, 0.5)
	if tower_cell.is_empty():
		return {}

	# 最终出口格：在 E 面、翻两次后高度 4.5、正下方就是塔列。
	var ec := _rotate_point(q2, _center(), exit_cell_local)
	if absf(ec.y - 4.5) > 0.02:
		return {}
	if absf(ec.x - tower_after.x) > 0.02 or absf(ec.z - tower_after.z) > 0.02:
		return {}

	# 第二段三块必须落在 A2 / O2 的墙脚（第一翻后世界高度 0.5），
	# 并且翻两次后的 x/z 能拼成 1→2 的接近阶梯，最后是出口下的 2 米跳台。
	var s2_step_i := int(template["s2_step_i"])
	var s2_step_j := int(template["s2_step_j"])
	var s2_base_i := int(template["s2_base_i"])
	var s2_base_j := int(template["s2_base_j"])
	var s2_fall_i := int(template["s2_fall_i"])
	var s2_fall_j := int(template["s2_fall_j"])
	for cell_data in [
		[a2, s2_step_i, s2_step_j],
		[a2, s2_base_i, s2_base_j],
		[str(OPPOSITE_FACE[a2]), s2_fall_i, s2_fall_j],
	]:
		var cell_face := str(cell_data[0])
		var cell_i := int(cell_data[1])
		var cell_j := int(cell_data[2])
		if cell_key(cell_face, cell_i, cell_j) == exit_cell_key:
			return {}
		var fp := _rotate_point(
			q1, _center(), cell_local_position(cell_face, cell_i, cell_j)
		)
		if absf(fp.y - 0.5) > 0.02:
			return {}

	var step2_xz := _rotate_point(qf2, _center(), _rotate_point(q1, _center(), cell_local_position(a2, s2_step_i, s2_step_j)))
	var base2_xz := _rotate_point(qf2, _center(), _rotate_point(q1, _center(), cell_local_position(a2, s2_base_i, s2_base_j)))
	var fall2_xz := _rotate_point(qf2, _center(), _rotate_point(q1, _center(), cell_local_position(str(OPPOSITE_FACE[a2]), s2_fall_i, s2_fall_j)))
	if _dist_xz(fall2_xz, base2_xz) > 0.02:
		return {}
	if absf(_dist_xz(base2_xz, tower_after) - 1.0) > 0.02:
		return {}
	if absf(_dist_xz(step2_xz, base2_xz) - 1.0) > 0.02:
		return {}
	if _dist_xz(step2_xz, tower_after) < 0.5:
		return {}

	return {
		"a1": a1,
		"a2": a2,
		"base_i": base_i,
		"step_i": step_i,
		"fall1_face": o1,
		"fall1_i": fall1_i,
		"s2_step_face": a2,
		"s2_step_i": s2_step_i,
		"s2_step_j": s2_step_j,
		"s2_base_face": a2,
		"s2_base_i": s2_base_i,
		"s2_base_j": s2_base_j,
		"s2_fall_face": str(OPPOSITE_FACE[a2]),
		"s2_fall_i": s2_fall_i,
		"s2_fall_j": s2_fall_j,
		"exit_face": exit_face,
		"exit_i": ei,
		"exit_j": ej,
		"tower_face": a2,
		"tower_i": int(tower_cell["i"]),
		"tower_j": int(tower_cell["j"]),
	}


func _center() -> Vector3:
	return Vector3(0.0, cube_half_extent, 0.0)


func _rotate_point(q: Quaternion, center: Vector3, p: Vector3) -> Vector3:
	return center + q * (p - center)


func _dist_xz(a: Vector3, b: Vector3) -> float:
	return absf(a.x - b.x) + absf(a.z - b.z)


func _find_face_cell_after(q: Quaternion, face_key: String, world_target: Vector3, height: float) -> Dictionary:
	for i in range(GRID_N):
		for j in range(GRID_N):
			var p := _rotate_point(q, _center(), cell_local_position(face_key, i, j))
			if (
				absf(p.y - height) <= 0.02
				and absf(p.x - world_target.x) <= 0.02
				and absf(p.z - world_target.z) <= 0.02
			):
				return {"i": i, "j": j}
	return {}


# ---------------------------------------------------------------- 受保护格子

## 解法经过的格子及其邻格不铺禅图，否则会挡住积木/球/攀爬路线。
func _build_protected_cells() -> void:
	_maze_protected.clear()

	# 第一段：base / step / fall 与第一层新地面的攀爬区。
	_protect_face_cell(_a1, _base_i, 0, 2)
	_protect_face_cell(_a1, _step_i, 0, 2)
	if _fall1_face != "":
		_protect_face_cell(_fall1_face, _fall1_i, 0, 2)

	# 第二段：基座/踏板 + 软糖基座 + 拱心石格 + 最终塔/出口附近。
	_protect_face_cell(_s2_step_face, _s2_step_i, _s2_step_j, 2)
	_protect_face_cell(_s2_base_face, _s2_base_i, _s2_base_j, 2)
	_protect_face_cell(_s2_fall_face, _s2_fall_i, _s2_fall_j, 2)
	_protect_face_cell(_tower_face, _tower_i, _tower_j, 2)
	_protect_face_cell(_exit_face, _exit_i, _exit_j, 1)

	# 固定建筑块：它们自己占格，随机禅图不要和它们重叠。
	for spec in FIXED_BLOCKS:
		_protect_cell_key(_cell_key(spec["cell"] as Vector3i))

	# 右边墙 R 上的两颗球：金球 R(1,1)、墙脚青球 R(2,0)。
	_protect_face_cell("R", 1, 1, 2)
	_protect_face_cell("R", 2, 0, 2)

	# 自由建造经过的区域：
	#  - 第一翻后，第一段塔/青球在 +Z 墙角落（旧 D 面，本来就没有禅图）。
	#  - 第二翻前，第二段 3 米塔在 B 新地面的 z=1.5；第一段塔在 z=2.5。
	#    两者都对应 B 面 j=3/4 一带，清掉这里的禅图。
	_protect_face_cell("B", 1, 3, 2)

	# 第二段新路线：固定软糖占 B(3,1)，玩家要在它左边的 B(4,1)/B(5,1)
	# 往它下面补两块；把这一带的落点和站位也清干净，避免禅图挡路。
	_protect_face_cell("B", 5, 1, 1)

	# 新增固定软糖所在的 (3,11,3)，避免禅图先占导致 _spawn_fixed_blocks 跳过。
	_protect_cell_key(_cell_key(Vector3i(3, 11, 3)))


func _protect_face_cell(face_key: String, i: int, j: int, radius: int) -> void:
	for di in range(-radius, radius + 1):
		for dj in range(-radius, radius + 1):
			var ni := i + di
			var nj := j + dj
			if ni < 0 or ni >= GRID_N or nj < 0 or nj >= GRID_N:
				continue
			_protect_cell_key(
				_cell_key(_local_to_cell(cell_local_position(face_key, ni, nj)))
			)


func _protect_cell_key(key: String) -> void:
	_maze_protected[key] = true


# ---------------------------------------------------------------- 出口休眠

func _setup_exit_pan() -> void:
	var pan := get_node_or_null("ExitPan") as Node3D
	if pan == null:
		return
	_pan_capture = pan.get_node_or_null("CaptureArea") as Area3D
	if _pan_capture != null:
		_pan_capture.monitoring = false
	_pan_vortex = pan.get_node_or_null("Vortex") as Node3D
	_pan_beam = pan.get_node_or_null("PortalBeam") as Node3D
	_pan_light = pan.get_node_or_null("PortalFillLight") as OmniLight3D
	if _pan_vortex != null:
		_pan_vortex.visible = false
	if _pan_beam != null:
		_pan_beam.visible = false
	if _pan_light != null:
		_pan_light.light_energy = 0.0


## 把锅摆到随机的出口格上，锅口朝房间里面。
func _apply_exit_pan_transform() -> void:
	var pan := get_node_or_null("ExitPan") as Node3D
	if pan == null:
		return
	var out: Vector3 = FACE_DEFS[_exit_face]["out"]
	var inward := -out
	var cell_center := cell_local_position(_exit_face, _exit_i, _exit_j)
	var origin := cell_center + out * 0.5 + inward * 0.1

	var x_axis := inward.cross(Vector3.UP)
	if x_axis.length_squared() < 0.0001:
		x_axis = Vector3.RIGHT
	x_axis = x_axis.normalized()
	var y_axis := inward
	var z_axis := x_axis.cross(y_axis).normalized()
	pan.transform = Transform3D(Basis(x_axis, y_axis, z_axis), origin)


func is_exit_active() -> bool:
	return _exit_active


## L 翻成底面：出口只“通电”，门变黄，捕获区保持关闭，等拱心石。
func _arm_exit() -> void:
	if _exit_active:
		return
	_exit_armed = true
	_exit_door_open = false
	_update_exit_door_frame()
	if _pan_capture != null:
		_pan_capture.set_deferred("monitoring", false)
	if _pan_vortex != null:
		_pan_vortex.visible = false
	if _pan_beam != null:
		_pan_beam.visible = false
	if _pan_light != null:
		_pan_light.light_energy = 0.0
	_spawn_keystone_ghost()
	build_state_changed.emit()


## 拱心石落位：门变蓝、捕获区打开、显示吸收特效。
func _activate_exit() -> void:
	if _exit_active:
		return
	_exit_active = true
	_exit_armed = false
	_exit_door_open = true
	_update_exit_door_frame()
	if _pan_capture != null:
		_pan_capture.set_deferred("monitoring", true)
	if _pan_vortex != null:
		_pan_vortex.visible = true
	if _pan_beam != null:
		_pan_beam.visible = true
	if _pan_light != null:
		_pan_light.light_energy = 0.5
	_hide_keystone_ghost()
	exit_activated.emit()
	build_state_changed.emit()


## 收回拱心石：回到“待命黄”，捕获区关闭，幽灵块回来。
func _deactivate_exit() -> void:
	if not _exit_active and not _exit_armed:
		return
	_exit_active = false
	_exit_armed = true
	_exit_door_open = false
	_update_exit_door_frame()
	if _pan_capture != null:
		_pan_capture.set_deferred("monitoring", false)
	if _pan_vortex != null:
		_pan_vortex.visible = false
	if _pan_beam != null:
		_pan_beam.visible = false
	if _pan_light != null:
		_pan_light.light_energy = 0.0
	_clear_keystone_fx()
	_spawn_keystone_ghost()
	build_state_changed.emit()


func _spawn_keystone_ghost() -> void:
	if _keystone_ghost != null and is_instance_valid(_keystone_ghost):
		_keystone_ghost.visible = true
		return
	if _hint_root == null:
		return
	var ghost := Node3D.new()
	ghost.name = "KeystoneGhost"
	ghost.position = _cell_to_local(KEYSTONE_CELL)
	ghost.add_to_group("level6_keystone_ghost")
	_hint_root.add_child(ghost)

	var fill := MeshInstance3D.new()
	var fill_mesh := BoxMesh.new()
	fill_mesh.size = Vector3(0.92, 0.92, 0.92)
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.02, 0.02, 0.02, 0.10)
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.emission_enabled = true
	fill_mat.emission = DE_STIJL_YELLOW
	fill_mat.emission_energy_multiplier = 0.5
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill.mesh = fill_mesh
	fill.material_override = fill_mat
	ghost.add_child(fill)

	# 黄色边 + 顶部黄块，和普通块的蓝/红区分开。
	_add_marker_edges(ghost, DE_STIJL_YELLOW)
	var cap := MeshInstance3D.new()
	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.28, 0.06, 0.28)
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = DE_STIJL_YELLOW
	cap_mat.emission_enabled = true
	cap_mat.emission = DE_STIJL_YELLOW
	cap_mat.emission_energy_multiplier = 1.4
	cap.mesh = cap_mesh
	cap.material_override = cap_mat
	cap.position = Vector3(0.0, 0.49, 0.0)
	ghost.add_child(cap)
	_keystone_ghost = ghost


func _hide_keystone_ghost() -> void:
	if _keystone_ghost != null and is_instance_valid(_keystone_ghost):
		_keystone_ghost.visible = false


func _spawn_keystone_link() -> void:
	if _keystone_link != null and is_instance_valid(_keystone_link):
		return
	var block: Node3D = null
	for entry in _placed:
		var cell: Vector3i = entry["cell"]
		if _cell_key(cell) == _cell_key(KEYSTONE_CELL):
			block = entry.get("node") as Node3D
			break
	var pan := get_node_or_null("ExitPan") as Node3D
	if block == null or pan == null:
		return
	var start := to_local(block.global_position)
	var finish := to_local(pan.global_position)
	var delta := finish - start
	var length := delta.length()
	if length < 0.1:
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, length)
	var line := MeshInstance3D.new()
	line.name = "KeystoneLink"
	line.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = DE_STIJL_YELLOW
	mat.emission_enabled = true
	mat.emission = DE_STIJL_YELLOW
	mat.emission_energy_multiplier = 1.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	line.material_override = mat
	line.transform = Transform3D(Basis.looking_at(delta.normalized(), Vector3.UP), (start + finish) * 0.5)
	add_child(line)
	_keystone_link = line


func _play_keystone_burst() -> void:
	var block: Node3D = null
	for entry in _placed:
		var cell: Vector3i = entry["cell"]
		if _cell_key(cell) == _cell_key(KEYSTONE_CELL):
			block = entry.get("node") as Node3D
			break
	if block == null:
		return
	var origin := to_local(block.global_position)
	var colors := [DE_STIJL_RED, DE_STIJL_BLUE, DE_STIJL_YELLOW, DE_STIJL_INK]
	for i in range(10):
		var cube := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.16, 0.16, 0.16)
		var mat := StandardMaterial3D.new()
		var col: Color = colors[i % colors.size()]
		mat.albedo_color = col
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.6
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cube.mesh = box
		cube.material_override = mat
		cube.position = origin
		add_child(cube)
		_keystone_fx.append(cube)
		var angle := TAU * float(i) / 10.0
		var dir := Vector3(cos(angle), sin(angle) * 0.6 + 0.4, sin(angle) * 0.7).normalized()
		var target := origin + dir * (1.0 + 0.4 * float(i % 3))
		var tw := create_tween()
		tw.set_parallel(true)
		tw.set_trans(Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_OUT)
		tw.tween_property(cube, "position", target, 0.55)
		tw.tween_property(cube, "scale", Vector3.ZERO, 0.55)
		tw.tween_property(cube, "rotation", Vector3(angle, angle * 1.7, angle * 0.6), 0.55)
		tw.chain().tween_callback(cube.queue_free)


func _clear_keystone_fx() -> void:
	if _keystone_link != null and is_instance_valid(_keystone_link):
		_keystone_link.queue_free()
	_keystone_link = null
	for node in _keystone_fx:
		if is_instance_valid(node):
			node.queue_free()
	_keystone_fx.clear()


# ---------------------------------------------------------------- 翻面

func can_flip() -> bool:
	return not _gravity_busy and super.can_flip()


## 翻面方向不再限制：推哪一面都能翻。金框/青框只标出“翻成底面会触发
## 下一件事”的目标面（B 让青球亮起，L 打开出口）。其他面翻了只是改变重力，
## 不会推进阶段，玩家可以继续翻到目标面。
func request_flip(collision_normal: Vector3, player: Node3D) -> bool:
	if _gravity_busy:
		flip_blocked.emit("重力还在翻转，等积木落定。")
		return false
	if _stage >= 2:
		flip_blocked.emit("已经是最后一层了：沿台阶上到跳台，跳进出口锅。")
		return false
	if build_charges > 0:
		flip_blocked.emit("先把本段积木全部放下，再翻面。")
		return false

	var ok: bool = super.request_flip(collision_normal, player)
	if not ok:
		flip_blocked.emit("这一面现在翻不动：看看墙脚是不是被挡住了。")
	return ok


## 本关的建造积木和禅图方块都粘在立方体上，翻面时跟着一起转，
## 不应该像自由刚体那样把墙脚卡住。只让真正的 MovableBox 阻止翻面。
func _is_flip_blocked_by_box(collision_normal: Vector3, player: Node3D) -> bool:
	var toward_wall := -_snap_to_axis(collision_normal)
	if toward_wall.length_squared() < 0.5:
		return false

	var contact := player.global_position + toward_wall * 0.5
	var along_wall := Vector3.UP.cross(toward_wall)
	if along_wall.length_squared() < 0.0001:
		along_wall = Vector3.RIGHT
	else:
		along_wall = along_wall.normalized()

	for box in _collect_obstacle_boxes():
		if not is_instance_valid(box):
			continue
		if box.is_in_group("level6_build") or box.is_in_group("level6_maze"):
			continue
		var offset := box.global_position - contact
		if absf(offset.dot(Vector3.UP)) > flip_junction_clearance:
			continue
		if absf(offset.dot(along_wall)) > flip_junction_clearance:
			continue
		if absf(offset.dot(toward_wall)) > flip_junction_clearance:
			continue
		return true
	return false


## 翻面一开始就按住玩家；父类在旋转结束时会重新打开物理，
## 这里保持到落块合模完成，避免角色穿过正在下落的积木。
func _on_flip_started() -> void:
	_set_settle_hold(true)


func _set_settle_hold(hold: bool) -> void:
	_settle_hold = hold
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return
	if hold:
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		if "target_velocity" in player:
			player.target_velocity = Vector3.ZERO
		player.set_physics_process(false)
	else:
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO
		player.set_physics_process(true)


func _keep_player_frozen() -> void:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return
	if player.is_physics_processing():
		player.set_physics_process(false)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


func _check_crush() -> bool:
	for node in _crush_watch:
		if not is_instance_valid(node):
			continue
		if _block_overlaps_player(node as Node3D):
			_trigger_crush()
			return true
	return false


## 只比较真实碰撞盒，并稍微收缩，避免玩家站在块顶时被误判。
func _block_overlaps_player(block: Node3D) -> bool:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null or block == null:
		return false

	var player_shape := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var player_box: AABB
	if player_shape != null and player_shape.shape is BoxShape3D:
		var ps := (player_shape.shape as BoxShape3D).size
		var pscale := player_shape.global_transform.basis.get_scale()
		var psize := Vector3(ps.x * absf(pscale.x), ps.y * absf(pscale.y), ps.z * absf(pscale.z))
		player_box = AABB(player_shape.global_position - psize * 0.5, psize)
	else:
		player_box = AABB(player.global_position - Vector3(0.34, 0.34, 0.34), Vector3(0.68, 0.68, 0.68))
	player_box = player_box.grow(-0.03)

	var block_shape := block.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var block_box: AABB
	if block_shape != null and block_shape.shape is BoxShape3D:
		var bs := (block_shape.shape as BoxShape3D).size
		var bscale := block_shape.global_transform.basis.get_scale()
		var bsize := Vector3(bs.x * absf(bscale.x), bs.y * absf(bscale.y), bs.z * absf(bscale.z))
		block_box = AABB(block_shape.global_position - bsize * 0.5, bsize)
	else:
		block_box = AABB(block.global_position - Vector3(0.47, 0.47, 0.47), Vector3(0.94, 0.94, 0.94))
	block_box = block_box.grow(-0.03)

	return player_box.intersects(block_box)


func _trigger_crush() -> void:
	if _crush_triggered:
		return
	_crush_triggered = true
	_gravity_busy = true
	_set_settle_hold(true)
	player_crushed.emit()


func _on_flip_finished() -> void:
	# Q/E 转立方体也发 flip_finished，但地面没变。
	# 用“地面 == 本段目标面”+ 当前 stage 做一次性推进。
	var new_floor := _floor_face()
	var advanced := false
	if _stage == 0 and new_floor == _a1:
		_stage = 1
		advanced = true
	elif _stage == 1 and new_floor == _a2:
		_stage = 2
		advanced = true

	if advanced:
		_flip_count += 1

	_set_settle_hold(true)
	await _settle_blocks(true)
	if not is_inside_tree() or _crush_triggered:
		return
	_set_settle_hold(false)

	if advanced:
		if _stage == 1:
			_allowed_flip_face = _a2
			_activate_orb(1)
		elif _stage == 2:
			_allowed_flip_face = ""
			_activate_exit()
		_update_flip_frame()
		_refresh_place_markers()
	build_state_changed.emit()


# ---------------------------------------------------------------- 球

func _spawn_orbs() -> void:
	_orbs_root = Node3D.new()
	_orbs_root.name = "Orbs"
	add_child(_orbs_root)

	# 两颗球都放在右边墙 R 上，开局就看得见；青色球先是暗的，
	# 第一翻后仍在 R 面上，降到可拿的高度并点亮。
	var orb0_pos := cell_local_position("R", 1, 1)
	_orbs.append(_make_orb(0, orb0_pos, Color(1.0, 0.78, 0.28), true))

	# 青球放在右边墙脚：第一翻后会落到 +Z 墙角落的 (2.5, 3.5, 2.5)，
	# 正好在玩家用第一段积木叠出的 2 米台上方。
	var orb1_pos := cell_local_position("R", 2, 0)
	_orbs.append(_make_orb(1, orb1_pos, Color(0.35, 0.9, 1.0), false))

	_update_orb_visuals()


func _make_orb(index: int, local_pos: Vector3, color: Color, active: bool) -> Dictionary:
	var area := Area3D.new()
	area.name = "Orb%d" % index
	area.position = local_pos
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = false
	area.add_to_group("level6_orb")

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	shape.shape = sphere
	area.add_child(shape)

	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.32
	sm.height = 0.64
	sm.radial_segments = 24
	sm.rings = 12
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.2
	mat.metallic = 0.1
	mat.roughness = 0.25
	mesh.material_override = mat
	area.add_child(mesh)

	# 白色玻璃罩 + 一圈主色箍，和软糖工作室统一。
	var wrapper_color := GUMMY_WHITE
	var wrapper := Node3D.new()
	wrapper.name = "Wrapper"
	area.add_child(wrapper)

	var wrapper_shell := MeshInstance3D.new()
	var shell_mesh := SphereMesh.new()
	shell_mesh.radius = 0.37
	shell_mesh.height = 0.74
	shell_mesh.radial_segments = 24
	shell_mesh.rings = 12
	wrapper_shell.mesh = shell_mesh
	var wrapper_mat := StandardMaterial3D.new()
	wrapper_mat.albedo_color = Color(wrapper_color.r, wrapper_color.g, wrapper_color.b, 0.20)
	wrapper_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wrapper_mat.metallic = 0.0
	wrapper_mat.roughness = 0.22
	wrapper_mat.emission_enabled = true
	wrapper_mat.emission = wrapper_color
	wrapper_mat.emission_energy_multiplier = 0.06
	wrapper_shell.material_override = wrapper_mat
	wrapper.add_child(wrapper_shell)

	var band := MeshInstance3D.new()
	var band_mesh := TorusMesh.new()
	band_mesh.inner_radius = 0.35
	band_mesh.outer_radius = 0.395
	band_mesh.rings = 24
	band_mesh.ring_segments = 8
	band.mesh = band_mesh
	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = color
	band_mat.roughness = 0.3
	band_mat.emission_enabled = true
	band_mat.emission = band_mat.albedo_color
	band_mat.emission_energy_multiplier = 0.08
	band.material_override = band_mat
	band.rotation_degrees = Vector3(0.0, 0.0, 90.0)
	wrapper.add_child(band)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.4
	torus.outer_radius = 0.47
	torus.rings = 24
	torus.ring_segments = 8
	ring.mesh = torus
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = color
	ring_mat.emission_enabled = true
	ring_mat.emission = color
	ring_mat.emission_energy_multiplier = 1.3
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	ring.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	area.add_child(ring)

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.1
	light.omni_range = 2.4
	light.shadow_enabled = false
	area.add_child(light)

	_orbs_root.add_child(area)
	area.body_entered.connect(_on_orb_body_entered.bind(index))
	var entry := {
		"index": index,
		"node": area,
		"local_pos": local_pos,
		"active": active,
		"collected": false,
		"wrapped": true,
		"unwrapping": false,
		"mesh_mat": mat,
		"candy_mesh": mesh,
		"wrapper": wrapper,
		"wrapper_shell": wrapper_shell,
		"wrapper_mat": wrapper_mat,
		"ring": ring,
		"light": light,
	}
	return entry


func _update_orb_visuals() -> void:
	for entry in _orbs:
		var area := entry["node"] as Area3D
		if area == null:
			continue
		var active := bool(entry["active"])
		var collected := bool(entry["collected"])
		var unlocked := active and not collected
		var wrapped := bool(entry.get("wrapped", true)) and not collected
		var unwrapping := bool(entry.get("unwrapping", false))
		area.visible = not collected

		var wrapper := entry.get("wrapper") as Node3D
		if wrapper != null:
			wrapper.visible = (wrapped or unwrapping) and not collected
		var candy_mesh := entry.get("candy_mesh") as MeshInstance3D
		if candy_mesh != null:
			candy_mesh.visible = (not wrapped) or unwrapping
		var mesh_mat := entry.get("mesh_mat") as StandardMaterial3D
		if mesh_mat != null:
			mesh_mat.emission_energy_multiplier = 2.2 if (unlocked and (not wrapped or unwrapping)) else 0.22
		var ring := entry.get("ring") as MeshInstance3D
		if ring != null:
			ring.visible = unlocked and not wrapped
		var light := entry.get("light") as OmniLight3D
		if light != null:
			light.light_energy = 1.1 if (unlocked and not wrapped) else 0.0
		# body_entered 回调里不能直接改 monitoring；统一用 deferred。
		area.set_deferred("monitoring", unlocked)


## 玻璃罩打开：罩子缩小旋转飞走，里面的圆糖块弹出来。
func _open_wrapper(index: int) -> void:
	if index < 0 or index >= _orbs.size():
		return
	var entry: Dictionary = _orbs[index]
	if bool(entry.get("collected", false)) or not bool(entry.get("wrapped", true)):
		return
	if bool(entry.get("unwrapping", false)):
		return
	entry["unwrapping"] = true
	var wrapper := entry.get("wrapper") as Node3D
	var candy_mesh := entry.get("candy_mesh") as MeshInstance3D
	if candy_mesh != null:
		candy_mesh.visible = true
		candy_mesh.scale = Vector3(0.55, 0.55, 0.55)
	var tw := create_tween()
	if wrapper != null:
		tw.set_parallel(true)
		tw.tween_property(wrapper, "scale", Vector3(0.02, 0.02, 0.02), 0.32) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.tween_property(wrapper, "rotation_degrees:y", 150.0, 0.32)
	if candy_mesh != null:
		tw.tween_property(candy_mesh, "scale", Vector3.ONE, 0.38) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(_finish_unwrap.bind(index))
	_update_orb_visuals()


func _finish_unwrap(index: int) -> void:
	if index < 0 or index >= _orbs.size():
		return
	var entry: Dictionary = _orbs[index]
	entry["wrapped"] = false
	entry["unwrapping"] = false
	var wrapper := entry.get("wrapper") as Node3D
	if wrapper != null:
		wrapper.visible = false
	_update_orb_visuals()


func _activate_orb(index: int) -> void:
	if index < 0 or index >= _orbs.size():
		return
	var entry: Dictionary = _orbs[index]
	if bool(entry["collected"]):
		return
	entry["active"] = true
	# 目标底面翻成地面时，糖纸当场打开。
	_open_wrapper(index)
	_update_orb_visuals()
	_collect_if_overlapping(index)


## 激活球时，玩家可能已经站在它里面（例如翻面后正好落在台顶）。
## Area 的 body_entered 只会在“进入”时触发，这里补一次重叠检查。
func _collect_if_overlapping(index: int) -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	if not is_inside_tree():
		return
	if index < 0 or index >= _orbs.size():
		return
	var entry: Dictionary = _orbs[index]
	if bool(entry["collected"]) or not bool(entry["active"]):
		return
	var area := entry["node"] as Area3D
	if area == null:
		return
	for body in area.get_overlapping_bodies():
		if body is Node3D and (
			(body as Node3D).is_in_group("player") or (body as Node3D).name == "Player"
		):
			_collect_orb(index)
			return


func _on_orb_body_entered(body: Node3D, index: int) -> void:
	if body == null:
		return
	if not (body.is_in_group("player") or body.name == "Player"):
		return
	_collect_orb(index)


func _collect_orb(index: int) -> void:
	if index < 0 or index >= _orbs.size():
		return
	var entry: Dictionary = _orbs[index]
	if bool(entry["collected"]) or not bool(entry["active"]):
		return
	entry["collected"] = true
	entry["active"] = false
	_update_orb_visuals()
	_orbs_collected += 1
	var gained := ORB_BLOCKS_SECOND if index == 1 else ORB_BLOCKS
	build_charges += gained

	# 球只负责补积木；目标底面由 stage 决定。青球不再直接开门——
	# 门在把 L 面翻成底面时由 _activate_exit() 打开。
	var next_face := _allowed_flip_face
	orb_collected.emit(index, gained, next_face)
	build_state_changed.emit()


# ---------------------------------------------------------------- 建造

func cell_local_position(face_key: String, i: int, j: int) -> Vector3:
	var def: Dictionary = FACE_DEFS.get(face_key, {})
	if def.is_empty():
		return Vector3.ZERO
	var origin: Vector3 = def["origin"]
	var u: Vector3 = def["u"]
	var v: Vector3 = def["v"]
	return origin + u * (float(i) - 2.5) + v * (float(j) - 2.5)


## 同一个物理格子可能同时属于两个面（棱/角），所以用格子坐标做唯一键。
func cell_key(face_key: String, i: int, j: int) -> String:
	return _cell_key(_local_to_cell(cell_local_position(face_key, i, j)))


func _exit_cell_key() -> String:
	return cell_key(_exit_face, _exit_i, _exit_j)


func place_block(face_key: String, i: int, j: int) -> bool:
	if _gravity_busy or flipping:
		return false
	if build_charges <= 0:
		return false
	if not FACE_DEFS.has(face_key):
		return false
	if i < 0 or i >= GRID_N or j < 0 or j >= GRID_N:
		return false

	var local_pos := cell_local_position(face_key, i, j)
	var cell := _local_to_cell(local_pos)
	var key := _cell_key(cell)
	if key == _exit_cell_key():
		return false
	if _occupied.has(key) or _maze_cells.has(key):
		return false

	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return false
	var world_pos := to_global(local_pos)
	if world_pos.distance_to(player.global_position) > BUILD_REACH:
		return false
	if _overlaps_player(world_pos, player.global_position):
		return false

	var block := _make_block(local_pos)
	var boxes := get_node_or_null("staticboxes")
	if boxes == null:
		boxes = self
	boxes.add_child(block)

	_placed.append({
		"face": face_key,
		"i": i,
		"j": j,
		"cell": cell,
		"key": key,
		"node": block,
		"stage": _stage,
	})
	_occupied[key] = true
	build_charges -= 1
	build_state_changed.emit()
	_refresh_place_markers()
	return true


func undo_last_block() -> bool:
	if _placed.is_empty():
		return false
	# 翻面之后，上一段的积木已经合模成新地形（比如第一段的 2 米跳台），
	# 再收回会拆掉通路；只允许收回本段刚放下的积木。
	if _gravity_busy or flipping:
		flip_blocked.emit("重力还在翻转，等积木落定再收。")
		return false
	var entry: Dictionary = _placed.back()
	if int(entry.get("stage", -1)) != _stage:
		flip_blocked.emit("上一段的积木已经合模成地形，不能再收回。")
		return false
	_placed.pop_back()
	var node = entry.get("node")
	if is_instance_valid(node):
		node.queue_free()
	_rebuild_occupancy()
	build_charges += 1
	build_state_changed.emit()
	_refresh_place_markers()
	if not _gravity_busy:
		_settle_blocks.call_deferred()
	return true


# ---------------------------------------------------------------- 3D 建造提示

## 翻面边框 + 自由建造的四格落点提示。不再用右侧展开图/固定目标格。
func _spawn_build_hints() -> void:
	_hint_root = Node3D.new()
	_hint_root.name = "BuildHints"
	add_child(_hint_root)

	_flip_frame = Node3D.new()
	_flip_frame.name = "FlipFrame"
	_hint_root.add_child(_flip_frame)
	_update_flip_frame()

	_spawn_place_markers()


## 当前该翻的面：第一翻金色，第二翻青色，翻完隐藏。
func _update_flip_frame() -> void:
	if _flip_frame == null:
		return
	for child in _flip_frame.get_children():
		child.queue_free()
	_flip_frame_mat = null
	if _stage >= 2:
		_flip_frame.visible = false
		return

	var face := _a1 if _stage == 0 else _a2
	var color := FLIP_COLOR_A1 if _stage == 0 else FLIP_COLOR_A2
	_flip_frame.visible = true
	_build_face_frame(face, color)


func _build_face_frame(face_key: String, color: Color) -> void:
	var def: Dictionary = FACE_DEFS[face_key]
	var u: Vector3 = def["u"]
	var v: Vector3 = def["v"]
	var out: Vector3 = def["out"]
	var origin: Vector3 = def["origin"]
	# 墙面在格心平面外 0.5 米；边框稍微缩进一点，避免和墙脚/棱相交。
	var center := origin + out * 0.46
	var basis := Basis(u, v, u.cross(v))

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_flip_frame_mat = mat

	var extent := 2.94
	var bar_len := 5.88
	var bar_thick := 0.11
	var bar_depth := 0.08
	var specs := [
		[Vector3(0.0, extent, 0.0), Vector3(bar_len, bar_thick, bar_depth)],
		[Vector3(0.0, -extent, 0.0), Vector3(bar_len, bar_thick, bar_depth)],
		[Vector3(extent, 0.0, 0.0), Vector3(bar_thick, bar_len, bar_depth)],
		[Vector3(-extent, 0.0, 0.0), Vector3(bar_thick, bar_len, bar_depth)],
	]
	for spec in specs:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1] as Vector3
		mesh.mesh = box
		mesh.material_override = mat
		mesh.position = spec[0] as Vector3
		_flip_frame.add_child(mesh)

	_flip_frame.transform = Transform3D(basis, center)


# ---------------------------------------------------------------- 出口门

## 初始底面 D 上的 1 米门框：红色=关，绿色=金色球已经打开。
## 门框和翻面边框一样是立方体子节点，不会被裁切隐藏。
func _spawn_exit_door() -> void:
	_exit_door_frame = Node3D.new()
	_exit_door_frame.name = "ExitDoor"
	_hint_root.add_child(_exit_door_frame)
	_update_exit_door_frame()


func _unlock_exit_door() -> void:
	if _exit_door_open:
		return
	_exit_door_open = true
	_update_exit_door_frame()


func _update_exit_door_frame() -> void:
	if _exit_door_frame == null:
		return
	var color := EXIT_DOOR_COLOR_CLOSED
	if _exit_door_open:
		color = EXIT_DOOR_COLOR_OPEN
	elif _exit_armed:
		color = EXIT_DOOR_COLOR_ARMED
	# 门已经建好时只换颜色，避免 queue_free 的旧门框在当帧还留着红色。
	if _exit_door_frame.get_child_count() > 0 and _exit_door_mat != null:
		_exit_door_mat.albedo_color = color
		_exit_door_mat.emission = color
		return

	var def: Dictionary = FACE_DEFS[_exit_face]
	var u: Vector3 = def["u"]
	var v: Vector3 = def["v"]
	var out: Vector3 = def["out"]
	var center := cell_local_position(_exit_face, _exit_i, _exit_j) + out * 0.46
	var basis := Basis(u, v, u.cross(v))

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_exit_door_mat = mat

	var half := 0.53
	var bar_len := 1.06
	var bar_thick := 0.055
	var bar_depth := 0.06
	var specs := [
		[Vector3(0.0, half, 0.0), Vector3(bar_len, bar_thick, bar_depth)],
		[Vector3(0.0, -half, 0.0), Vector3(bar_len, bar_thick, bar_depth)],
		[Vector3(half, 0.0, 0.0), Vector3(bar_thick, bar_len, bar_depth)],
		[Vector3(-half, 0.0, 0.0), Vector3(bar_thick, bar_len, bar_depth)],
	]
	for spec in specs:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1] as Vector3
		mesh.mesh = box
		mesh.material_override = mat
		mesh.position = spec[0] as Vector3
		_exit_door_frame.add_child(mesh)

	_exit_door_frame.transform = Transform3D(basis, center)


## 四个自由建造落点标记：每 0.1 秒跟着主角周围四格移动。
func _spawn_place_markers() -> void:
	for idx in range(4):
		var body := StaticBody3D.new()
		body.name = "PlaceMarker%d" % idx
		body.collision_layer = GHOST_LAYER
		body.collision_mask = 0
		body.add_to_group("level6_place_marker")
		body.visible = false
		_hint_root.add_child(body)

		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = Vector3(1.0, 1.0, 1.0)
		shape.shape = box_shape
		shape.disabled = true
		body.add_child(shape)

		var color := GUMMY_CYAN
		var fill := MeshInstance3D.new()
		var fill_mesh := BoxMesh.new()
		fill_mesh.size = Vector3(0.82, 0.82, 0.82)
		var fill_mat := StandardMaterial3D.new()
		fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		fill_mat.albedo_color = Color(color.r, color.g, color.b, 0.035)
		fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fill_mat.emission_enabled = true
		fill_mat.emission = color
		fill_mat.emission_energy_multiplier = 0.35
		fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		fill.mesh = fill_mesh
		fill.material_override = fill_mat
		body.add_child(fill)

		var edge_mat := _add_marker_edges(body, color)
		_place_markers.append({
			"body": body,
			"shape": shape,
			"cell": Vector3i.ZERO,
			"valid": false,
			"hovered": false,
			"fill_mat": fill_mat,
			"edge_mat": edge_mat,
		})


## 用一个 0.9 米立方体的 12 条棱把落点框出来（4.x 没有 wireframe 材质）。
func _add_marker_edges(body: Node3D, color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var length := 0.9
	var half := 0.45
	var thick := 0.014
	for axis in range(3):
		for a in [-1, 1]:
			for b in [-1, 1]:
				var mesh := MeshInstance3D.new()
				var box := BoxMesh.new()
				var size := Vector3(thick, thick, thick)
				var pos := Vector3.ZERO
				if axis == 0:
					size = Vector3(length, thick, thick)
					pos = Vector3(0.0, float(a) * half, float(b) * half)
				elif axis == 1:
					size = Vector3(thick, length, thick)
					pos = Vector3(float(a) * half, 0.0, float(b) * half)
				else:
					size = Vector3(thick, thick, length)
					pos = Vector3(float(a) * half, float(b) * half, 0.0)
				box.size = size
				mesh.mesh = box
				mesh.material_override = mat
				mesh.position = pos
				body.add_child(mesh)
	return mat


## 玩家所在格：主角可能站在格线上，吸附到最近的格心（奇数双倍坐标）。
func _placement_player_cell(player: Node3D) -> Vector3i:
	var cell := _local_to_cell(to_local(player.global_position))
	cell.x = _snap_odd(cell.x)
	cell.y = _snap_odd(cell.y)
	cell.z = _snap_odd(cell.z)
	return cell


func _snap_odd(v: int) -> int:
	return v if (v % 2 != 0) else v + 1


## 前两段不允许提前占掉拱心石格和旧落块格；stage2 只由拱心石检查接管。
func _is_reserved_cell(cell: Vector3i) -> bool:
	if _stage >= 2:
		return false
	var key := _cell_key(cell)
	return key == _cell_key(KEYSTONE_CELL) or key == _cell_key(RESERVED_FALL_CELL)


## 计算四个候选格；有重力，所以显示的是块最终会落到的格子。
func _refresh_place_markers() -> void:
	var player := get_parent().get_node_or_null("Player") as Node3D
	var shown := 0
	if player != null:
		var pcell := _placement_player_cell(player)
		var down := _down_cell()
		# 四格必须沿“当前地面”的两条格子轴，而不是立方体局部 x/z。
		# 翻面后地面会换面，局部 x/z 可能有一根指向天上。
		var floor_def: Dictionary = FACE_DEFS[_floor_face()]
		var u: Vector3 = floor_def["u"]
		var v: Vector3 = floor_def["v"]
		var u_axis := Vector3i(int(round(u.x)) * 2, int(round(u.y)) * 2, int(round(u.z)) * 2)
		var v_axis := Vector3i(int(round(v.x)) * 2, int(round(v.y)) * 2, int(round(v.z)) * 2)
		var candidates: Array[Vector3i] = [
			pcell + u_axis,
			pcell - u_axis,
			pcell + v_axis,
			pcell - v_axis,
		]
		var seen: Dictionary = {}
		for cand in candidates:
			var res := _placement_landing(cand, down)
			if not bool(res.get("valid", false)):
				continue
			var landing: Vector3i = res["cell"]
			var key := _cell_key(landing)
			if seen.has(key):
				continue
			if _overlaps_player(to_global(_cell_to_local(landing)), player.global_position):
				continue
			seen[key] = true
			if shown >= _place_markers.size():
				break
			var entry: Dictionary = _place_markers[shown]
			var body := entry["body"] as StaticBody3D
			var shape := entry["shape"] as CollisionShape3D
			var marker_color := GUMMY_CYAN
			var fill_mat := entry.get("fill_mat") as StandardMaterial3D
			if fill_mat != null:
				fill_mat.albedo_color = Color(
					marker_color.r, marker_color.g, marker_color.b, 0.035
				)
				fill_mat.emission = marker_color
			var edge_mat := entry.get("edge_mat") as StandardMaterial3D
			if edge_mat != null:
				edge_mat.albedo_color = marker_color
				edge_mat.emission = marker_color
			entry["cell"] = landing
			entry["valid"] = true
			body.position = _cell_to_local(landing)
			body.set_meta("cell", landing)
			body.visible = true
			shape.disabled = false
			shown += 1

	for i in range(shown, _place_markers.size()):
		var entry: Dictionary = _place_markers[i]
		entry["valid"] = false
		entry["hovered"] = false
		var body := entry["body"] as StaticBody3D
		var shape := entry["shape"] as CollisionShape3D
		body.visible = false
		shape.disabled = true


func _placement_landing(cand: Vector3i, down: Vector3i) -> Dictionary:
	if _is_outside_room(cand):
		return {"valid": false}
	var key := _cell_key(cand)
	if _occupied.has(key) or _maze_cells.has(key) or key == _exit_cell_key():
		return {"valid": false}
	var cell := cand
	var guard := 0
	while not _cell_is_support(cell + down):
		cell += down
		guard += 1
		if guard > 16 or _is_outside_room(cell):
			return {"valid": false}
		var below_key := _cell_key(cell)
		if _occupied.has(below_key) or _maze_cells.has(below_key) or below_key == _exit_cell_key():
			return {"valid": false}
	return {"valid": true, "cell": cell}


func _marker_at_screen(screen_pos: Vector2) -> StaticBody3D:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var from := cam.project_ray_origin(screen_pos)
	var to := from + cam.project_ray_normal(screen_pos) * 2000.0
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to, GHOST_LAYER)
	params.collide_with_bodies = true
	params.collide_with_areas = false
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return null
	var body := hit.get("collider") as Node
	if body == null or not body.is_in_group("level6_place_marker"):
		return null
	return body as StaticBody3D


func _update_place_hover() -> void:
	var hovered := _marker_at_screen(get_viewport().get_mouse_position())
	if hovered != _hovered_marker:
		_hovered_marker = hovered
	for entry in _place_markers:
		entry["hovered"] = (entry["body"] as Node) == hovered


func _pulse_place_markers() -> void:
	for entry in _place_markers:
		var body := entry["body"] as StaticBody3D
		if body == null or not body.visible:
			continue
		var hovered := bool(entry.get("hovered", false))
		var pulse := 0.5 + 0.5 * sin(_hint_time * (7.0 if hovered else 1.6))
		var fill_mat := entry.get("fill_mat") as StandardMaterial3D
		if fill_mat != null:
			fill_mat.emission_energy_multiplier = (1.8 + 1.0 * pulse) if hovered else 0.35
			var c := fill_mat.albedo_color
			c.a = (0.42 + 0.3 * pulse) if hovered else 0.10
			fill_mat.albedo_color = c
		var edge_mat := entry.get("edge_mat") as StandardMaterial3D
		if edge_mat != null:
			edge_mat.emission_energy_multiplier = (1.8 + 1.2 * pulse) if hovered else 0.6


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_place_from_screen(mb.position)


func _place_from_screen(screen_pos: Vector2) -> void:
	if _gravity_busy or flipping:
		return
	var body := _marker_at_screen(screen_pos)
	if body == null:
		return
	var cell: Vector3i = body.get_meta("cell", Vector3i.ZERO)
	place_cell(cell)


## 自由建造：在悬停/落点格放一块。块已经在最终支撑位置，翻面时再跟着重力合模。
func place_cell(cell: Vector3i) -> bool:
	if _gravity_busy or flipping:
		return false
	if build_charges <= 0:
		build_refused.emit("积木用完了：先吃掉发光的球补充。")
		return false
	var key := _cell_key(cell)
	if _is_outside_room(cell) or _occupied.has(key) or _maze_cells.has(key):
		return false
	if key == _exit_cell_key():
		build_refused.emit("出口门上不能放积木。")
		return false

	var player := get_parent().get_node_or_null("Player") as Node3D
	var world_pos := to_global(_cell_to_local(cell))
	if player != null and _overlaps_player(world_pos, player.global_position):
		build_refused.emit("角色占着这一格，先让开。")
		return false

	var block := _make_block(_cell_to_local(cell))
	var boxes := get_node_or_null("staticboxes")
	if boxes == null:
		boxes = self
	boxes.add_child(block)
	_bounce_gummy(block)

	_placed.append({
		"face": "",
		"i": -1,
		"j": -1,
		"cell": cell,
		"key": key,
		"node": block,
		"stage": _stage,
	})
	_occupied[key] = true
	build_charges -= 1
	build_state_changed.emit()
	_refresh_place_markers()
	return true


# ---------------------------------------------------------------- 重力下坠

func _settle_blocks(allow_crush: bool = false) -> void:
	if _gravity_busy or _placed.is_empty():
		return
	_gravity_busy = true
	_set_settle_hold(true)
	_crush_watch.clear()
	if allow_crush:
		_crush_triggered = false

	var down := _down_cell()
	var order := _placed.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _cell_dot(a["cell"] as Vector3i, down) > _cell_dot(b["cell"] as Vector3i, down)
	)

	# 从最靠近新地面的积木开始排：先落下的会变成后来者的支撑。
	# 注意：不把玩家所在格当作支撑。否则玩家站在落块路线上时，
	# 积木会停在他头顶，最后合不成出口下的 2 米跳台。
	_occupied.clear()
	var moves: Array[Dictionary] = []
	for entry in order:
		var cell: Vector3i = entry["cell"]
		var start := cell
		var below := cell + down
		while not _cell_is_support(below):
			cell = below
			below = cell + down
		var key := _cell_key(cell)
		_occupied[key] = true
		if cell != start:
			moves.append({"entry": entry, "from": start, "to": cell})
		entry["cell"] = cell
		entry["key"] = key
		entry["local"] = _cell_to_local(cell)

	if moves.is_empty():
		_crush_watch.clear()
		_gravity_busy = false
		_set_settle_hold(false)
		build_state_changed.emit()
		return

	if allow_crush:
		for move in moves:
			var watched = move["entry"].get("node")
			if is_instance_valid(watched):
				_crush_watch.append(watched)

	for move in moves:
		var node = move["entry"].get("node")
		if not is_instance_valid(node):
			continue
		_set_block_collision(node, false)
		var target: Vector3 = move["entry"]["local"]
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_QUAD)
		tw.set_ease(Tween.EASE_IN)
		tw.tween_property(node, "position", target, 0.35)

	await get_tree().create_timer(0.37).timeout

	if not is_inside_tree():
		return
	if _crush_triggered:
		# 已经被砸中：不要恢复该次落块/玩家，等待重载场景。
		_crush_watch.clear()
		return

	# 如果玩家恰好站在落块的目标格里，先把玩家顶到这一列的最上面，
	# 再打开碰撞；否则玩家会被压在方块里。
	_unstick_player_from_blocks()
	_nudge_player_out_of_blocks()

	for move in moves:
		var node = move["entry"].get("node")
		if is_instance_valid(node):
			_set_block_collision(node, true)
			_bounce_gummy(node)

	_crush_watch.clear()
	_gravity_busy = false
	_set_settle_hold(false)
	build_state_changed.emit()


func _cell_is_support(cell: Vector3i) -> bool:
	if _is_outside_room(cell):
		return true
	if _occupied.has(_cell_key(cell)):
		return true
	if _maze_cells.has(_cell_key(cell)):
		return true
	return false


## 玩家所在格被积木占了：沿当前“上”方向找这一列最高的一块，
## 把玩家放到它上面。翻面后玩家常常正好站在 base 上，
## 会被落下来的 fall 覆盖，这个处理让他自然“被顶到台顶”。
func _unstick_player_from_blocks() -> void:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return
	var cell := _player_cell()
	if not _occupied.has(_cell_key(cell)):
		return
	var down := _down_cell()
	var up := Vector3i(-down.x, -down.y, -down.z)
	var top := cell
	while _occupied.has(_cell_key(top + up)):
		top += up
	var up_unit := Vector3(up).normalized()
	var stand_local := _cell_to_local(top) + up_unit * 0.86
	player.global_position = to_global(stand_local)
	if player is CharacterBody3D:
		(player as CharacterBody3D).velocity = Vector3.ZERO


## 兜底：如果碰撞恢复后玩家仍和某块相交，沿“上”方向挪到块顶。
## 正常情况下 _unstick 已经处理；这里防止多块重叠或玩家掉进侧缝。
func _nudge_player_out_of_blocks() -> void:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return
	var down := _down_cell()
	var up := -Vector3(down.x, down.y, down.z).normalized()
	var groups := ["level6_build", "level6_fixed"]
	for attempt in range(4):
		var hit: Node3D = null
		for group_name in groups:
			for node in get_tree().get_nodes_in_group(group_name):
				if node is Node3D and _block_overlaps_player(node as Node3D):
					hit = node as Node3D
					break
			if hit != null:
				break
		if hit == null:
			return
		player.global_position = hit.global_position + up * 0.86
		if player is CharacterBody3D:
			(player as CharacterBody3D).velocity = Vector3.ZERO


func _is_outside_room(cell: Vector3i) -> bool:
	if cell.y < 1 or cell.y > 11:
		return true
	if cell.x < -5 or cell.x > 5:
		return true
	if cell.z < -5 or cell.z > 5:
		return true
	return false


## 当前“下”方向在“双倍坐标”里的步进。
## 格子中心是 0.5/1.5/...，双倍后是 1/3/...（奇数），
## 所以走一格要 ±2，而不是 ±1。
func _down_cell() -> Vector3i:
	var out: Vector3 = FACE_DEFS[_floor_face()]["out"]
	return Vector3i(
		int(round(out.x)) * 2,
		int(round(out.y)) * 2,
		int(round(out.z)) * 2
	)


## 外法线朝世界下方的那一面就是当前地面。
func _floor_face() -> String:
	var best := "D"
	var best_dot := -INF
	for face_key in FACE_DEFS:
		var def: Dictionary = FACE_DEFS[face_key]
		var out_local: Vector3 = def["out"]
		var out_world: Vector3 = (global_transform.basis * out_local).normalized()
		var dot := out_world.dot(Vector3.DOWN)
		if dot > best_dot:
			best_dot = dot
			best = face_key
	return best


func _player_cell() -> Vector3i:
	var player := get_parent().get_node_or_null("Player") as Node3D
	if player == null:
		return Vector3i.ZERO
	return _local_to_cell(to_local(player.global_position))


# ---------------------------------------------------------------- 禅图方块

func _spawn_maze_blocks() -> void:
	for face_key in SIDE_FACES:
		for i in range(GRID_N):
			for j in range(1, GRID_N):
				if _maze_protected.has(_cell_key(_local_to_cell(cell_local_position(face_key, i, j)))):
					continue
				if face_key == _exit_face and _near_cell(i, j, _exit_i, _exit_j):
					continue
				if _rng.randf() > MAZE_DENSITY:
					continue
				_add_maze_block(face_key, i, j)

	# 顶面只铺中间 4×4，四周留一圈，翻面后不会顶到新的地面或出口。
	for i in range(1, GRID_N - 1):
		for j in range(1, GRID_N - 1):
			if _maze_protected.has(_cell_key(_local_to_cell(cell_local_position("U", i, j)))):
				continue
			if _rng.randf() > MAZE_DENSITY:
				continue
			_add_maze_block("U", i, j)


func _near_cell(i: int, j: int, ci: int, cj: int) -> bool:
	return absi(i - ci) <= 1 and absi(j - cj) <= 1


func _add_maze_block(face_key: String, i: int, j: int) -> void:
	var local_pos := cell_local_position(face_key, i, j)
	var cell := _local_to_cell(local_pos)
	var key := _cell_key(cell)
	if key == _cell_key(UPPER_LILAC_CELL):
		return
	if _maze_cells.has(key):
		return
	if _maze_protected.has(key):
		return
	if key == _exit_cell_key():
		return

	var boxes := get_node_or_null("staticboxes")
	if boxes == null:
		return
	var block := _make_maze_block(local_pos, face_key)
	boxes.add_child(block)
	_maze_cells[key] = true
	_maze_face_cells["%s:%d:%d" % [face_key, i, j]] = true


func _make_maze_block(local_pos: Vector3, face_key: String) -> StaticBody3D:
	_maze_serial += 1
	var body := StaticBody3D.new()
	body.name = "StaticBox_Maze%d" % _maze_serial
	body.position = local_pos
	body.add_to_group("level6_maze")
	body.set_meta("maze_face", face_key)

	var mesh := MeshInstance3D.new()
	mesh.name = "GummyMesh"
	mesh.scale = Vector3.ONE * 0.90
	# 禅图方块：每颗从高饱和软糖色里取一个，作为彩色障碍。
	var tone_hash := absi(
		int(round(local_pos.x * 10.0)) * 31
		+ int(round(local_pos.y * 10.0)) * 17
		+ int(round(local_pos.z * 10.0)) * 7
	)
	var accent: Color = MAZE_PALETTE[tone_hash % MAZE_PALETTE.size()]
	var mat := ShaderMaterial.new()
	mat.shader = BLOCK_SHADER
	mat.set_shader_parameter("base_color", accent)
	mat.set_shader_parameter("accent_color", accent)
	mat.set_shader_parameter("ink", MAZE_GRID_COLOR)
	mat.set_shader_parameter("pattern_seed", float(tone_hash % 97) * 0.11)
	mat.set_shader_parameter("roughness", 0.10)
	mat.set_shader_parameter("glow", 0.06)
	mat.set_shader_parameter("socket", 0.0)
	mat.set_shader_parameter("gummy_alpha", 0.80)
	mat.set_shader_parameter("gummy_softness", 0.018)
	mat.set_shader_parameter("rim_strength", 0.36)
	mat.set_shader_parameter("saturation", 0.55)
	mat.set_shader_parameter("color_value", 0.87)
	mesh.mesh = _ensure_gummy_mesh()
	mesh.material_override = mat
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box_shape
	body.add_child(shape)
	return body


# ---------------------------------------------------------------- 固定建筑块

func _spawn_fixed_blocks() -> void:
	var boxes := get_node_or_null("staticboxes")
	if boxes == null:
		return
	for spec in FIXED_BLOCKS:
		var cell: Vector3i = spec["cell"]
		var key := _cell_key(cell)
		if _maze_cells.has(key):
			continue
		var block := _make_fixed_block(_cell_to_local(cell), str(spec.get("tone", "black")))
		boxes.add_child(block)
		# 固定块也参与占格/支撑，玩家不能穿/叠进去。
		_maze_cells[key] = true


func _make_fixed_block(local_pos: Vector3, tone: String) -> StaticBody3D:
	_maze_serial += 1
	var body := StaticBody3D.new()
	body.name = "StaticBox_Fixed%d" % _maze_serial
	body.position = local_pos
	body.add_to_group("level6_fixed")

	var mesh := MeshInstance3D.new()
	mesh.name = "GummyMesh"
	mesh.scale = Vector3.ONE * 0.94
	var accent: Color = GUMMY_BY_TONE.get(tone, GUMMY_MAGENTA)
	var base_color := GUMMY_WHITE.lerp(accent, 0.55)
	var mat := ShaderMaterial.new()
	mat.shader = BLOCK_SHADER
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("accent_color", accent)
	mat.set_shader_parameter("ink", GUMMY_INK)
	mat.set_shader_parameter("pattern_seed", absf(local_pos.x + local_pos.z) * 0.13)
	mat.set_shader_parameter("roughness", 0.09)
	mat.set_shader_parameter("glow", 0.10)
	mat.set_shader_parameter("socket", 0.0)
	mat.set_shader_parameter("gummy_alpha", 0.84)
	mat.set_shader_parameter("gummy_softness", 0.012)
	mat.set_shader_parameter("rim_strength", 0.58)
	mat.set_shader_parameter("saturation", 0.60)
	mat.set_shader_parameter("color_value", 0.88)
	mesh.mesh = _ensure_gummy_mesh()
	mesh.material_override = mat
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box_shape
	body.add_child(shape)
	return body


# ---------------------------------------------------------------- 展开图状态

func get_build_state() -> Dictionary:
	var player := get_parent().get_node_or_null("Player") as Node3D
	var player_pos := Vector3.ZERO
	if player != null:
		player_pos = player.global_position

	var floor_face := _floor_face()
	var down := _down_cell()
	var reachable: Dictionary = {}
	var occupied_at: Dictionary = {}
	var obstacle_at: Dictionary = {}
	var stacks: Dictionary = {}
	var exit_key := _exit_cell_key()

	# 每块积木只画在“它所属的那个面”上。
	# 否则底排格子同时属于两个面，展开图会出现重影。
	for entry in _placed:
		var display_id := _display_cell_id(entry, floor_face)
		if not display_id.is_empty():
			occupied_at[display_id] = true

	for face_key in FACE_DEFS:
		for i in range(GRID_N):
			for j in range(GRID_N):
				var cell_id := "%s:%d:%d" % [face_key, i, j]
				var local_pos := cell_local_position(face_key, i, j)
				var key := _cell_key(_local_to_cell(local_pos))

				if _maze_cells.has(key):
					obstacle_at[cell_id] = true
					continue

				if key == exit_key:
					continue
				if _occupied.has(key):
					continue
				if player == null:
					continue

				var world_pos := to_global(local_pos)
				if (
					world_pos.distance_to(player_pos) <= BUILD_REACH
					and not _overlaps_player(world_pos, player_pos)
				):
					reachable[cell_id] = true

	# 地面上连续摞起来的积木，在展开图格子里标个数字。
	for entry in _placed:
		var cell: Vector3i = entry["cell"]
		var base := cell
		while _occupied.has(_cell_key(base + down)):
			base += down
		var base_fi := _face_cell_index(floor_face, base)
		if base_fi.is_empty():
			continue
		var count := 0
		var cursor := base
		while _occupied.has(_cell_key(cursor)):
			count += 1
			cursor -= down
		if count <= 0:
			continue
		stacks["%s:%d:%d" % [floor_face, base_fi["i"], base_fi["j"]]] = count

	var hint_cells: Array[Dictionary] = []
	if _stage == 0:
		hint_cells.append({"face": _a1, "i": _base_i, "j": 0})
		hint_cells.append({"face": _a1, "i": _step_i, "j": 0})
		if _fall1_face != "":
			hint_cells.append({"face": _fall1_face, "i": _fall1_i, "j": 0})
	elif _stage == 1:
		hint_cells.append({"face": _s2_step_face, "i": _s2_step_i, "j": _s2_step_j})
		hint_cells.append({"face": _s2_base_face, "i": _s2_base_i, "j": _s2_base_j})
		hint_cells.append({"face": _s2_fall_face, "i": _s2_fall_i, "j": _s2_fall_j})

	var orb_markers: Array[Dictionary] = []
	for entry in _orbs:
		if bool(entry["collected"]) or not bool(entry["active"]):
			continue
		var node := entry["node"] as Node3D
		if node == null:
			continue
		var idx := _face_column_index(floor_face, _local_to_cell(node.position))
		if idx.is_empty():
			continue
		orb_markers.append({
			"index": int(entry["index"]),
			"face": floor_face,
			"i": int(idx["i"]),
			"j": int(idx["j"]),
		})

	return {
		"charges": build_charges,
		"max_charges": maxi(3, build_charges),
		"reachable": reachable,
		"occupied_at": occupied_at,
		"obstacle_at": obstacle_at,
		"stacks": stacks,
		"player_cell": _player_marker(player),
		"exit_cell": {"face": _exit_face, "i": _exit_i, "j": _exit_j},
		"exit_active": _exit_active,
		"exit_armed": _exit_armed,
		"exit_door_open": _exit_door_open,
		"keystone_placed": _keystone_placed,
		"keystone_cell": {"face": "B", "i": 3, "j": 1},
		"floor_face": floor_face,
		"flip_face": _allowed_flip_face,
		"hidden_faces": get_hidden_faces(),
		"block_count": _placed.size(),
		"can_undo": (
			not _placed.is_empty()
			and not _gravity_busy
			and not flipping
			and int(_placed.back().get("stage", -1)) == _stage
		),
		"flip_count": _flip_count,
		"maze_count": _maze_cells.size(),
		"stage": _stage,
		"stage_total": 2,
		"orbs_collected": _orbs_collected,
		"orbs_total": _orbs.size(),
		"hint_cells": hint_cells,
		"orb_markers": orb_markers,
		"a1": _a1,
		"a2": _a2,
	}


## 积木在展开图上的显示位置：优先它被放置时所在的面，
## 只有那个面已经装不下它（例如掉成了室内方块）时才改画到地面。
func _display_cell_id(entry: Dictionary, floor_face: String) -> String:
	var cell: Vector3i = entry["cell"]
	var original_face := str(entry.get("face", ""))
	var original := _face_cell_index(original_face, cell)
	if not original.is_empty():
		return "%s:%d:%d" % [original_face, original["i"], original["j"]]

	# 掉下来的积木不在原来的墙面上，但仍在某一列里：
	# 把它归到它落下的那一列，展开图用层数表示高度。
	var floor_index := _face_column_index(floor_face, cell)
	if not floor_index.is_empty():
		return "%s:%d:%d" % [floor_face, floor_index["i"], floor_index["j"]]

	for face_key in FACE_DEFS:
		var idx := _face_cell_index(face_key, cell)
		if not idx.is_empty():
			return "%s:%d:%d" % [face_key, idx["i"], idx["j"]]
	return ""


## 只按面内坐标找格子，不管积木离这个面有多远。
## 用于把一摞积木都归到地面同一格（高度另有 stacks 显示）。
func _face_column_index(face_key: String, cell: Vector3i) -> Dictionary:
	var def: Dictionary = FACE_DEFS.get(face_key, {})
	if def.is_empty():
		return {}
	var local := _cell_to_local(cell)
	var origin: Vector3 = def["origin"]
	var u: Vector3 = def["u"]
	var v: Vector3 = def["v"]
	var du := (local - origin).dot(u)
	var dv := (local - origin).dot(v)
	var i := int(round(du + 2.5))
	var j := int(round(dv + 2.5))
	if i < 0 or i >= GRID_N or j < 0 or j >= GRID_N:
		return {}
	if absf(du + 2.5 - float(i)) > 0.01 or absf(dv + 2.5 - float(j)) > 0.01:
		return {}
	return {"i": i, "j": j}


func _face_cell_index(face_key: String, cell: Vector3i) -> Dictionary:
	var def: Dictionary = FACE_DEFS.get(face_key, {})
	if def.is_empty():
		return {}
	var local := _cell_to_local(cell)
	var origin: Vector3 = def["origin"]
	var u: Vector3 = def["u"]
	var v: Vector3 = def["v"]
	var i := int(round((local - origin).dot(u) + 2.5))
	var j := int(round((local - origin).dot(v) + 2.5))
	if i < 0 or i >= GRID_N or j < 0 or j >= GRID_N:
		return {}
	var expected := cell_local_position(face_key, i, j)
	if expected.distance_to(local) > 0.01:
		return {}
	return {"i": i, "j": j}


## 与 cube_world.update_cutaway_visibility 的判据保持一致。
func get_hidden_faces() -> Array[String]:
	var hidden: Array[String] = []
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return hidden
	var to_camera := (cam.global_position - get_center_global()).normalized()
	for face_key in FACE_DEFS:
		var def: Dictionary = FACE_DEFS[face_key]
		var out_local: Vector3 = def["out"]
		var out_world := (global_transform.basis * out_local).normalized()
		if out_world.dot(to_camera) > wall_visible_dot:
			hidden.append(face_key)
	return hidden


# ---------------------------------------------------------------- 网格与方块

func _cell_dot(cell: Vector3i, axis: Vector3i) -> int:
	return cell.x * axis.x + cell.y * axis.y + cell.z * axis.z


func _cell_key(cell: Vector3i) -> String:
	return "%d:%d:%d" % [cell.x, cell.y, cell.z]


func _cell_to_local(cell: Vector3i) -> Vector3:
	return Vector3(cell) * 0.5


func _local_to_cell(local_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(round(local_pos.x * 2.0)),
		int(round(local_pos.y * 2.0)),
		int(round(local_pos.z * 2.0))
	)


func _rebuild_occupancy() -> void:
	_occupied.clear()
	for entry in _placed:
		_occupied[String(entry.get("key", ""))] = true


func _overlaps_player(world_pos: Vector3, player_pos: Vector3) -> bool:
	return (
		absf(world_pos.x - player_pos.x) < 0.82
		and absf(world_pos.y - player_pos.y) < 0.82
		and absf(world_pos.z - player_pos.z) < 0.82
	)


## 玩家在展开图上的格子：始终投影到当前地面，
## 这样站在积木堆上时，标记也在堆底所在的格子里。
func _player_marker(player: Node3D) -> Dictionary:
	if player == null:
		return {}
	var floor_face := _floor_face()
	var def: Dictionary = FACE_DEFS[floor_face]
	var origin: Vector3 = def["origin"]
	var u: Vector3 = def["u"]
	var v: Vector3 = def["v"]
	var local := to_local(player.global_position)
	var i := int(round((local - origin).dot(u) + 2.5))
	var j := int(round((local - origin).dot(v) + 2.5))
	i = clampi(i, 0, GRID_N - 1)
	j = clampi(j, 0, GRID_N - 1)
	return {"face": floor_face, "i": i, "j": j}


func _set_block_collision(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = not enabled


## 一块“软弹方块”的共享网格：超椭球，视觉上是圆角软糖，
## 碰撞仍旧是 1 米立方体（见下面 BoxShape3D）。
func _ensure_gummy_mesh() -> ArrayMesh:
	if _gummy_mesh != null:
		return _gummy_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 18
	var segs := 28
	var e := 0.34
	for i in range(rings + 1):
		var v := -PI * 0.5 + PI * float(i) / float(rings)
		var cv := cos(v)
		var sv := sin(v)
		for j in range(segs):
			var u := -PI + TAU * float(j) / float(segs)
			var cu := cos(u)
			var su := sin(u)
			var x := signf(cv) * pow(absf(cv), e) * signf(cu) * pow(absf(cu), e)
			var y := signf(sv) * pow(absf(sv), e)
			var z := signf(cv) * pow(absf(cv), e) * signf(su) * pow(absf(su), e)
			st.add_vertex(Vector3(x, y, z) * 0.5)
	for i in range(rings):
		for j in range(segs):
			var a := i * segs + j
			var b := i * segs + (j + 1) % segs
			var c := (i + 1) * segs + j
			var d := (i + 1) * segs + (j + 1) % segs
			st.add_index(a)
			st.add_index(c)
			st.add_index(b)
			st.add_index(b)
			st.add_index(c)
			st.add_index(d)
	st.generate_normals()
	_gummy_mesh = st.commit()
	return _gummy_mesh


## 落地 Q 弹：只挤 Mesh，不动碰撞体，格子占位仍严格按 1 米立方体。
func _bounce_gummy(node: Node) -> void:
	var mesh := node.get_node_or_null("GummyMesh") as MeshInstance3D
	if mesh == null:
		return
	var base := mesh.scale
	if base.length_squared() < 0.0001:
		return
	var tw := create_tween()
	tw.tween_property(
		mesh, "scale", Vector3(base.x * 1.12, base.y * 0.84, base.z * 1.12), 0.07
	).set_trans(Tween.TRANS_SINE)
	tw.tween_property(
		mesh, "scale", Vector3(base.x * 0.97, base.y * 1.06, base.z * 0.97), 0.10
	).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mesh, "scale", base, 0.38).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _make_block(local_pos: Vector3) -> StaticBody3D:
	_block_serial += 1
	var body := StaticBody3D.new()
	body.name = "StaticBox_Build%d" % _block_serial
	body.position = local_pos
	body.add_to_group("level6_build")

	var mesh := MeshInstance3D.new()
	mesh.name = "GummyMesh"
	mesh.scale = Vector3.ONE * 0.94
	# 玩家块：第一段洋红、第二段蓝、最后一块紫色备用块。
	var accent := GUMMY_MAGENTA
	if _stage == 1:
		accent = GUMMY_BLUE
	elif _stage >= 2:
		accent = GUMMY_PURPLE
	var base_color := GUMMY_WHITE.lerp(accent, 0.24)
	var mat := ShaderMaterial.new()
	mat.shader = BLOCK_SHADER
	mat.set_shader_parameter("base_color", base_color)
	mat.set_shader_parameter("accent_color", accent)
	mat.set_shader_parameter("ink", GUMMY_INK)
	mat.set_shader_parameter("pattern_seed", float(_block_serial) * 0.37)
	mat.set_shader_parameter("roughness", 0.07)
	mat.set_shader_parameter("glow", 0.16 if _stage >= 2 else 0.05)
	mat.set_shader_parameter("socket", 0.0)
	mat.set_shader_parameter("gummy_alpha", 0.80)
	mat.set_shader_parameter("gummy_softness", 0.010)
	mat.set_shader_parameter("rim_strength", 0.64)
	mat.set_shader_parameter("saturation", 0.78)
	mat.set_shader_parameter("color_value", 0.92)
	mesh.mesh = _ensure_gummy_mesh()
	mesh.material_override = mat
	body.add_child(mesh)

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = Vector3(1.0, 1.0, 1.0)
	shape.shape = box_shape
	body.add_child(shape)
	return body


## 地板被裁切后，用一个不参与碰撞的淡色网格提示 1m 格子。
func _spawn_floor_grid() -> void:
	var root := Node3D.new()
	root.name = "FloorGrid"
	add_child(root)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.35, 0.35, 0.36, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var half := int(cube_half_extent)
	var length := cube_half_extent * 2.0
	for k in range(-half, half + 1):
		var a := MeshInstance3D.new()
		var mesh_a := BoxMesh.new()
		mesh_a.size = Vector3(0.012, 0.008, length)
		a.mesh = mesh_a
		a.material_override = mat
		a.position = Vector3(float(k), 0.02, 0.0)
		root.add_child(a)

		var b := MeshInstance3D.new()
		var mesh_b := BoxMesh.new()
		mesh_b.size = Vector3(length, 0.008, 0.012)
		b.mesh = mesh_b
		b.material_override = mat
		b.position = Vector3(0.0, 0.02, float(k))
		root.add_child(b)
