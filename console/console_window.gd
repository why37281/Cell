extends Window

@onready var text_edit = $VSplitContainer/MarginContainer/PanelContainer/VBoxContainer/TextEdit
@onready var rich_text = $VSplitContainer/VBoxContainer/ScrollContainer/MarginContainer/RichTextLabel
@onready var run_button = $VSplitContainer/MarginContainer/PanelContainer/VBoxContainer/HBoxContainer/Run
@onready var export_button = $VSplitContainer/MarginContainer/PanelContainer/VBoxContainer/HBoxContainer/Export


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_text_edit_focus_entered() -> void:
	text_edit.highlight_current_line = true



func _on_text_edit_focus_exited() -> void:
	
	text_edit.highlight_current_line = false


func _on_close_requested() -> void:
	hide()

func append_output(text: String):
	"""增量追加输出文本（应带换行符）"""
	rich_text.append_text(text)

func set_output(text: String):
	"""全量替换输出文本"""
	rich_text.text = text

func clear_output():
	rich_text.text = ""


func _on_run_pressed() -> void:
	var code = text_edit.text
	if code.is_empty():
		return
	text_edit.text = ""
	Console.execute_full(code)

func _on_export_pressed() -> void:
	Console._auto_export()


func _on_export_loadable_pressed() -> void:
	Console.export_logs_to_file()


func _on_load_pressed() -> void:
	$FileDialog.visible = true
	#TODO turn into popup()

func _on_clean_pressed() -> void:
	pass # Replace with function body.


func _on_file_dialog_file_selected(path: String) -> void:
	Console.load_logs_from_file(path)
