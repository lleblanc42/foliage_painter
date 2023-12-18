@tool
extends Control

const PAINT = "Paint"
const SINGLE = "Single"
const ERASE = "Erase"

const btn_group = preload("res://Addons/foliage_painter/ui/btn_group/element_group.tres")
const element_res = preload("res://Addons/foliage_painter/ui/element.tscn")
const element_res_property = preload("res://Addons/foliage_painter/scripts/element_property.gd")

signal elements_selected(pattern_paths)
signal element_added(path)
signal elements_removed(path)
signal brush_size_changed()
signal update_block_data()

#工具列表
@onready var toolList:GridContainer = $VBoxContainer/ToolBG/ToolContainer/ToolListContainer/toolList
#场景元素列表
@onready var elementsList:GridContainer = $VBoxContainer/ToolBG/ToolContainer/ElementsListContainer/ElementsList
#@onready var _margin_spin_box : SpinBox = $VBoxContainer/MarginContainer/MarginSpinBox
#工具名字
@onready var toolName:Label = $VBoxContainer/ToolBG/ToolContainer/ToolDetail/ToolName
#笔刷大小
@onready var brushSize:SpinBox = $VBoxContainer/ToolBG/ToolContainer/ToolDetail/HBoxContainer/BrushSizeSpin
#属性面板
@onready var propertyPanel:VBoxContainer = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel

@onready var element_name:Label = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/NameLabel
@onready var density:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/DensityBox/densitySpin
@onready var radius:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/RadiusBox/radiusSpin
@onready var yOffset_min:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/YOffsetBox/minSpin
@onready var yOffset_max:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/YOffsetBox/maxSpin
@onready var scale_min:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/ScaleBox/minSpin
@onready var scale_max:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/ScaleBox/MaxSpin
@onready var rotate_min:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/RotateBox/minSpin
@onready var rotate_max:SpinBox = $VBoxContainer/ToolBG/ToolContainer/Split/PropertyBG/PropertyPanel/RotateBox/MaxSpin

#正在被选择显示属性的element index
var selected_element_index:int = -1

var _file_dialog = null
var _preview_provider : EditorResourcePreview = null
#工具模式
var tool_mode:String = SINGLE
#操作模式
var mode:int = 0
#历史笔刷尺寸
var _brush_size_history:int = 100

func _ready():
	selected_element_index = -1
	propertyPanel.visible = false
	initTool()

func initTool():
	for node in toolList.get_children():
		if node.name == SINGLE:
			node.button_pressed = true
			tool_mode = SINGLE
			toolName.text = SINGLE
			node.get_node("nameLabel")
		else:
			pass
#			node.button_pressed = false
		toggle_tool()

func setup_dialogs(base_control):
	_file_dialog = FileDialog.new()
	_file_dialog.access = FileDialog.ACCESS_RESOURCES
	_file_dialog.mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.add_filter("*.tscn ; TSCN files")
	_file_dialog.file_selected.connect(_on_FileDialog_file_selected)
	_file_dialog.hide()
	base_control.add_child(_file_dialog)


func set_preview_provider(provider : EditorResourcePreview):
	assert(_preview_provider == null)
	assert(provider != null)
	_preview_provider = provider
	_preview_provider.preview_invalidated.connect(_on_EditorResourcePreview_preview_invalidated)


func _exit_tree():
	print("exit from tree")
	if _file_dialog != null:
		_file_dialog.queue_free()
		_file_dialog = null

func load_elements(patterns):
	for node in elementsList.get_children():
		node.element_select.disconnect(_on_element_selected)
		node.show_property.disconnect(_on_show_element_property)
		elementsList.remove_child(node)

	for dic in patterns:
		pass
		add_element(dic["path"],dic["selected"],dic["number"])


func add_element(scene_path,is_selected:bool=false,number:int=0):
	var element = element_res.instantiate()
	var godot_theme = EditorInterface.get_editor_theme()
	var default_icon = godot_theme.get_icon("PackedScene", "EditorIcons")
	var pattern_name = scene_path.get_file().get_basename()
	var i = elementsList.get_child_count()

	element.name = pattern_name

	element.get_script()
	element.icon = element.get_node_or_null("icon")
	element.checkBox = element.get_node_or_null("CheckBox")
	element.count = element.get_node_or_null("count")
	element.icon.texture = default_icon
	element.checkBox.button_group = btn_group
	element.property = element_res_property.new()
	element.element_select.connect(_on_element_selected)
	element.show_property.connect(_on_show_element_property)
	element.index = i
	element.path = scene_path
	element.update_number(number)

	if element and is_selected == true:
		element.selected = true
		element.checkBox.button_pressed = true

	elementsList.add_child(element)

	_preview_provider.queue_resource_preview(scene_path, self, "_on_EditorResourcePreview_preview_loaded", i)


func _on_EditorResourcePreview_preview_loaded(path, texture,preview, index):
	if texture != null:
		elementsList.get_child(index).icon.texture = texture

func _on_EditorResourcePreview_preview_invalidated(path):
	pass

#显示选中的element的属性
func _on_show_element_property(index):
	selected_element_index = index
	propertyPanel.visible = true
	var element = elementsList.get_child(index)
	show_property(element.name,element.property)
	pass

func remove_element(scene_path):
	print("在remove里被调用")
	var i = find_elment_index(scene_path)
	if i != -1:
#		_item_list.remove_item(i)
		var node = elementsList.get_child(i)
		node.element_select.disconnect(_on_element_selected)
		node.show_property.disconnect(_on_show_element_property)
		elementsList.remove_child(node)

#根据资源地址查找资源在GridContainer里的索引
func find_elment_index(path):
	for i in range(0,elementsList.get_child_count()):
		var child = elementsList.get_child(i)
		if child.path == path:
			return i
#	for child in elementsList.get_children():
#		if child.path == path:
#			return child.index

func select_element(path):
	var i = find_elment_index(path)
	if i != -1:
		var element = elementsList.get_child(i)
		element.checkBox.button_pressed = true
		element.selected = true

func _on_element_selected():
	var selected = []
	for node in elementsList.get_children():
		if node.selected == true:
			selected.append(node.path)
	emit_signal("elements_selected", selected)

#func get_configured_margin() -> float:
#	return _margin_spin_box.value


func _on_AddButton_pressed():
	_file_dialog.popup_centered_ratio(0.7)


func _on_RemoveButton_pressed():
	var removed := []
	for node in elementsList.get_children():
		if node.selected == true:
			removed.append(node.path)
	emit_signal("elements_removed", removed)


func _on_FileDialog_file_selected(fpath):
	print("fpath: ",fpath)
	emit_signal("element_added", fpath)


func _on_tool_toggled(button_pressed, tool_name):
	var node := toolList.get_node_or_null(tool_name)
	if node != null:
#		node.get_node("status").visible = button_pressed
		if button_pressed:
			tool_mode = tool_name
			toolName.text = tool_name
			toggle_tool()

#切换工具
func toggle_tool():
	match tool_mode:
		PAINT:
			brushSize.value = _brush_size_history
			brushSize.editable = true
		SINGLE:
			brushSize.value = 20
			brushSize.editable = false
		ERASE:
			brushSize.value = _brush_size_history
			brushSize.editable = true

func _on_brush_size_spin_value_changed(value):
	pass # Replace with function body.
	print("brush_size: ",value)
	if tool_mode != SINGLE:
		_brush_size_history = value
	emit_signal("brush_size_changed")

func on_change_brush_size(value):
	_brush_size_history = brushSize.value
	var temp = _brush_size_history + value
	if temp < 1:
		temp = 1
	if temp > 8192:
		temp = 8192
	brushSize.value = temp
	emit_signal("brush_size_changed")

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
	
#更新属性
func _on_property_changed(value, key):
	if selected_element_index == -1:
		return
	var element = elementsList.get_child(selected_element_index)
	element.property.update(key,value)
	match key:
		"yOffsetMin":
			yOffset_max.value = element.property.yOffsetMax
		"scaleMin":
			scale_max.value = element.property.scaleMax
		"rotateMin":
			rotate_max.value = element.property.rotateMax

#获取element属性
func get_element_property(path:String) -> ElementProperty:
	var i = find_elment_index(path)
	var element := elementsList.get_child(i)
	return element.property

#更新场景上的实例数量
func update_element_number(path:String,value:int):
	var i = find_elment_index(path)
	if i != -1:
		var node = elementsList.get_child(i)
		node.update_number(value)

#更新分块数据
func _on_update_button_pressed():
	emit_signal("update_block_data")
