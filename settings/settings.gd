# settings.gd — 设置主界面
extends Control

const NAV_ITEMS: Array[Dictionary] = [
	{ "name": "游戏", "id": "game" },
	{ "name": "声音", "id": "audio" },
	{ "name": "画面", "id": "video" },
]

@onready var nav_tree: Tree = $NavTree
@onready var page_container: ScrollContainer = $PageContainer
@onready var page_margin: MarginContainer = $PageContainer/PageMargin
@onready var back_btn: Button = $Back

var page_cache: Dictionary = {}

func _ready():
	_build_nav_tree()
	nav_tree.item_selected.connect(_on_nav_item_selected)
	back_btn.pressed.connect(_on_back_pressed)

	# 默认选中导航第一项
	var root = nav_tree.get_root()
	if root:
		var first = root.get_first_child()
		if first:
			first.select(0)

func _build_nav_tree():
	nav_tree.clear()
	var root = nav_tree.create_item()
	for item_def in NAV_ITEMS:
		_create_item(root, item_def)

func _create_item(parent: TreeItem, def: Dictionary, path_prefix: String = "") -> TreeItem:
	var item = nav_tree.create_item(parent)
	item.set_text(0, def["name"])
	var full_id = path_prefix + def["id"] if path_prefix.is_empty() else path_prefix + "/" + def["id"]
	item.set_metadata(0, full_id)
	if def.has("children"):
		for child_def in def["children"]:
			_create_item(item, child_def, full_id)
	return item

func _on_nav_item_selected():
	var item = nav_tree.get_selected()
	if not item:
		return
	var page_id = item.get_metadata(0)
	if page_id:
		show_page(page_id)

func show_page(page_id: String):
	# 将当前页面从场景树移除（不销毁，保留在缓存中复用）
	for child in page_margin.get_children():
		page_margin.remove_child(child)

	if not page_cache.has(page_id):
		var path = "res://settings/pages/%s/index.tscn" % page_id
		if ResourceLoader.exists(path):
			var page = load(path).instantiate()
			page_cache[page_id] = page
		else:
			push_error("设置页面不存在: " + path)
			Console.print_error("设置页面不存在: " + path)
			return

	var page = page_cache[page_id]
	page_margin.add_child(page)

func _on_back_pressed():
	get_tree().change_scene_to_file("res://scene/start.tscn")
