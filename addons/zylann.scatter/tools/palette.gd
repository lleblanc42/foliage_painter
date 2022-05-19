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
#@onready var _item_list : ItemList = $VBoxContainer/ItemList
#场景元素列表
@onready var elementsList:GridContainer = $VBoxContainer/ScrollContainer/ElementsList
@onready var _margin_spin_box : SpinBox = $VBoxContainer/MarginContainer/MarginSpinBox
#属性面板
@onready var propertyPanel:VBoxContainer = $VBoxContainer/PropertyPanel

@onready var element_name:Label = $VBoxContainer/PropertyPanel/NameLabel
@onready var density:SpinBox = $VBoxContainer/PropertyPanel/DensityBox/densitySpin
@onready var radius:SpinBox = $VBoxContainer/PropertyPanel/RadiusBox/radiusSpin
@onready var yOffset_min:SpinBox = $VBoxContainer/PropertyPanel/YOffsetBox/minSpin
@onready var yOffset_max:SpinBox = $VBoxContainer/PropertyPanel/YOffsetBox/maxSpin
@onready var scale_min:SpinBox = $VBoxContainer/PropertyPanel/ScaleBox/minSpin
@onready var scale_max:SpinBox = $VBoxContainer/PropertyPanel/ScaleBox/MaxSpin
@onready var rotate_min:SpinBox = $VBoxContainer/PropertyPanel/RotateBox/minSpin
@onready var rotate_max:SpinBox = $VBoxContainer/PropertyPanel/RotateBox/MaxSpin

#正在被选择显示属性的element index
var selected_element_index:int = -1


var _file_dialog = null
var _preview_provider : EditorResourcePreview = null
var _logger = Logger.get_for(self)

func _ready():
	selected_element_index = -1
	propertyPanel.visible = false
	initTool()

func initTool():
	for node in toolList.get_children():
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
#	_item_list.clear()
	for node in elementsList.get_children():
		elementsList.remove_child(node)
	#print("Loading ", len(patterns), " patterns")
	for scene in patterns:
		add_pattern(scene.resource_path)


func add_pattern(scene_path):
	var element = element_res.instantiate()
	var godot_theme = EditorPlugin.new().get_editor_interface().get_base_control().theme
	var default_icon = godot_theme.get_icon("PackedScene", "EditorIcons")
	var pattern_name = scene_path.get_file().get_basename()
	var i = elementsList.get_child_count()
	elementsList.add_child(element)
	element.connect("element_select",_on_element_selected)
	element.connect("show_property",_on_show_element_property)
	element.name = pattern_name
	element.icon.texture = default_icon
	element.checkBox.visible = false
	element.index = i
	element.path = scene_path
	element.button_group = btn_group
	
	_preview_provider.queue_resource_preview(scene_path, self, "_on_EditorResourcePreview_preview_loaded", i)


func _on_EditorResourcePreview_preview_loaded(path, texture,preview, index):
	if texture != null:
		elementsList.get_child(index).icon.texture = texture
	else:
		_logger.debug(str("No preview available for ", path))

func _on_EditorResourcePreview_preview_invalidated(path):
	# TODO Handle thumbnail invalidation
	#`path` is actually the folder in which the file was, NOT the file itself... useful for FileSystemDock only :(
	pass

#显示选中的element的属性
func _on_show_element_property(index):
	selected_element_index = index
	propertyPanel.visible = true
	var element = elementsList.get_child(index)
	show_property(element.name,element.property)
	pass

func remove_pattern(scene_path):
	var i = find_pattern(scene_path)
	if i != -1:
#		_item_list.remove_item(i)
		elementsList.remove_child(elementsList.get_child(i))

func find_pattern(path):
	for child in toolList.get_children():
		if child.path == path:
			return child.index

func select_pattern(path):
	var i = find_pattern(path)
	if i != -1:
		var element = elementsList.get_child(i)
		element.checkBox.pressed = true
		element.selected = true
#		_item_list.select(i)

func _on_element_selected():
	var selected = []
	for node in elementsList.get_children():
		if node.selected == true:
			selected.append(node.path)
	emit_signal("patterns_selected", selected)

func get_configured_margin() -> float:
	return _margin_spin_box.value


func _on_AddButton_pressed():
	_file_dialog.popup_centered_ratio(0.7)


func _on_RemoveButton_pressed():
	var removed := []
#	for item in _item_list.get_selected_items():
#		removed.append(_item_list.get_item_metadata(item))
	for node in elementsList.get_children():
		if node.selected == true:
			removed.append(node.path)
	emit_signal("patterns_removed", removed)


func _on_FileDialog_file_selected(fpath):
	print("fpath: ",fpath)
	emit_signal("pattern_added", fpath)


func can_drop_data(position, data):
	return data is Dictionary and data.get("type") == "files"


func drop_data(position, data):
	for file in data.files:
		emit_signal("pattern_added", file)


func _on_tool_toggled(button_pressed, tool_name):
	var node := toolList.get_node(tool_name)
	if node != null:
		node.get_node("status").visible = button_pressed

#显示element属性
func show_property(base_name:String,property:ElementProperty):
	element_name.text = base_name
	
	density.value = property.density
	radius.value = property.radius
	yOffset_min.value = property.yOffsetMin
	yOffset_max.value = property.yOffsetMax
	scale_min.value = property.scaleMin
	scale_max.value = property.scaleMax
	rotate_min.value = property.rotateMin
	rotate_max.value = property.rotateMax
	


func _on_property_changed(value, key):
	if selected_element_index == -1:
		return
	var element = elementsList.get_child(selected_element_index)
	element.property.update(key,value)
