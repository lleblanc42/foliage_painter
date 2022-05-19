@tool
extends TextureButton

#使用素材
signal element_select()
#选择素材
signal show_property(index)

@onready var over:ColorRect = $over
@onready var select:ColorRect = $select
@onready var icon:TextureRect = $icon
@onready var checkBox:CheckBox = $CheckBox
@onready var count:Label = $count
@onready var mask:ColorRect = $mask

#在列表里的索引
var index:int = 0
#场景地址
var path:String = ""

var selected:bool = false

var property:ElementProperty = preload("res://addons/zylann.scatter/ui/element_property.gd").new()

# Called when the node enters the scene tree for the first time.
func _ready():
	over.visible = false
	select.visible = false

func _on_check_box_toggled(button_pressed):
	print("button_pressed: ",button_pressed)
	mask.visible = !button_pressed
	selected = button_pressed
	emit_signal("element_select")


func _on_element_mouse_entered():
	checkBox.visible = true


func _on_element_mouse_exited():
	checkBox.visible = false
	over.visible = false


func _on_element_toggled(button_pressed):
	select.visible = button_pressed
	if button_pressed:
		emit_signal("show_property",index)
