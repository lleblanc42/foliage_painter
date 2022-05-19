@tool
extends Control
class_name Palette

const btn_group = preload("res://addons/zylann.scatter/ui/btn_group/element_group.tres")
const element_res = preload("res://addons/zylann.scatter/ui/element.tscn")
const Logger = preload("../util/logger.gd")

signal patterns_selected(pattern_paths)
signal pattern_added(path)
signal patterns_removed(path)

#工具列表
@onready var toolList:GridContainer = $VBoxContainer/ToolBG/ToolContainer/toolList
@onready var _item_list : ItemList = $VBoxContainer/ItemList
#场景元素列表
@onready var elementsList:GridContainer = $VBoxContainer/ScrollContainer/ElementsList
@onready var _margin_spin_box : SpinBox = $VBoxContainer/MarginContainer/MarginSpinBox

@onready var scale_min:SpinBox = $VBoxContainer/SetContainer/ScaleBox/minSpin
@onready var scale_max:SpinBox = $VBoxContainer/SetContainer/ScaleBox/MaxSpin
@onready var rotate_min:SpinBox = $VBoxContainer/SetContainer/RotateBox/minSpin
@onready var rotate_max:SpinBox = $VBoxContainer/SetContainer/RotateBox/MaxSpin

var _file_dialog = null
var _preview_provider : EditorResourcePreview = null
var _logger = Logger.get_for(self)

func _ready():
	initTool()

func initTool():
	for node in toolList.get_children():
		print(node.name)
		if node.name == "single":
			node.get_node("status").visible = true
			node.button_pressed = true
		else:
			node.get_node("status").visible = false

func setup_dialogs(base_control):
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.add_filter("*.tscn ; TSCN files")
	_file_dialog.connect("file_selected", _on_FileDialog_file_selected)
	_file_dialog.hide()
	base_control.add_child(_file_dialog)


func set_preview_provider(provider : EditorResourcePreview):
	assert(_preview_provider == null)
	assert(provider != null)
	_preview_provider = provider
	_preview_provider.connect("preview_invalidated", _on_EditorResourcePreview_preview_invalidated)


func _exit_tree():
	if _file_dialog != null:
		_file_dialog.queue_free()
		_file_dialog = null

func load_patterns(patterns):
	_item_list.clear()
	#print("Loading ", len(patterns), " patterns")
	for scene in patterns:
		add_pattern(scene.resource_path)


#func add_pattern(scene_path):
#	# TODO I need scene thumbnails from the editor
#	var godot_theme = EditorPlugin.new().get_editor_interface().get_base_control().theme
#
##	var list = Array(godot_theme.get_icon_list('EditorIcons'))
##	for icon_name in list:
##		print(icon_name)
#
#	var default_icon = godot_theme.get_icon("PackedScene", "EditorIcons") #PackedScene
#	var pattern_name = scene_path.get_file().get_basename()
#	var i = _item_list.get_item_count()
#	_item_list.add_item(pattern_name,default_icon)
#	_item_list.set_item_metadata(i, scene_path)
#
#	_preview_provider.queue_resource_preview(scene_path, self, "_on_EditorResourcePreview_preview_loaded", i)

func add_pattern(scene_path):
	var element = element_res.instantiate()
	var godot_theme = EditorPlugin.new().get_editor_interface().get_base_control().theme
	var default_icon = godot_theme.get_icon("PackedScene", "EditorIcons")
	var pattern_name = scene_path.get_file().get_basename()
	var i = elementsList.get_child_count()
	elementsList.add_child(element)
	element.name = pattern_name
	element.icon.texture = default_icon
	element.checkBox.visible = false
	element.index = i
	element.path = scene_path
	element.button_group = btn_group
	

	_preview_provider.queue_resource_preview(scene_path, self, "_on_EditorResourcePreview_preview_loaded", i)

#func _on_EditorResourcePreview_preview_loaded(path, texture,preview, i):
##	print("userdata: ",userdata)
##	var i = find_pattern(path)
##	if i == -1:
##		return
#	if texture != null:
#		_item_list.set_item_icon(i, texture)
#	else:
#		_logger.debug(str("No preview available for ", path))

func _on_EditorResourcePreview_preview_loaded(path, texture,preview, index):
	print("index: ",index)
	print(texture)
#	var i = find_pattern(path)
#	if i == -1:
#		return
	if texture != null:
		elementsList.get_child(index).icon.texture = texture
	else:
		_logger.debug(str("No preview available for ", path))

func _on_EditorResourcePreview_preview_invalidated(path):
	# TODO Handle thumbnail invalidation
	#`path` is actually the folder in which the file was, NOT the file itself... useful for FileSystemDock only :(
	pass


#func remove_pattern(scene_path):
#	var i = find_pattern(scene_path)
#	if i != -1:
#		_item_list.remove_item(i)

func remove_pattern(scene_path):
	var i = find_pattern(scene_path)
	if i != -1:
		_item_list.remove_item(i)

#func find_pattern(path):
#	for i in _item_list.get_item_count():
#		var scene_path = _item_list.get_item_metadata(i)
#		if scene_path == path:
#			return i
#	return -1

func find_pattern(path):
	for child in toolList.get_children():
		if child.path == path:
			return child.index

func select_pattern(path):
	var i = find_pattern(path)
	if i != -1:
		_item_list.select(i)

func _on_ItemList_multi_selected(_unused_index, _unused_selected):
	var selected = []
	for item in _item_list.get_selected_items():
		selected.append(_item_list.get_item_metadata(item))
	emit_signal("patterns_selected", selected)


func get_configured_margin() -> float:
	return _margin_spin_box.value


func _on_AddButton_pressed():
	_file_dialog.popup_centered_ratio(0.7)


func _on_RemoveButton_pressed():
	var removed := []
	for item in _item_list.get_selected_items():
		removed.append(_item_list.get_item_metadata(item))
	emit_signal("patterns_removed", removed)


func _on_FileDialog_file_selected(fpath):
	print("fpath: ",fpath)
	emit_signal("pattern_added", fpath)


func can_drop_data(position, data):
	return data is Dictionary and data.get("type") == "files"


func drop_data(position, data):
	for file in data.files:
		emit_signal("pattern_added", file)


func _on_tool_toggled(button_pressed, toolName):
	print("tool:",toolName," visible: ",button_pressed)
	var node := toolList.get_node(toolName)
	if node != null:
		node.get_node("status").visible = button_pressed

