@tool
extends TextureButton

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
#密度
var density:float = 0.0
#间距
var radius:float = 0.0
#高度随机偏移
#最小偏移
var yOffsetMin:float = 0.0
#最大偏移
var yOffsetMax:float = 0.0
var selected:bool = false

# Called when the node enters the scene tree for the first time.
func _ready():
	over.visible = false
	select.visible = false

func _on_check_box_toggled(button_pressed):
	print("button_pressed: ",button_pressed)
	mask.visible = !button_pressed


func _on_element_mouse_entered():
	checkBox.visible = true


func _on_element_mouse_exited():
	checkBox.visible = false
	over.visible = false


func _on_element_toggled(button_pressed):
	select.visible = button_pressed
