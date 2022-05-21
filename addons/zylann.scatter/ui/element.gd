@tool
extends TextureButton

#使用素材
signal element_select()
#选择素材
signal show_property(index)

@onready var icon:TextureRect = $icon
@onready var checkBox:CheckBox = $CheckBox
@onready var count:Label = $count

#在列表里的索引
var index:int = 0
#场景地址
var path:String = ""

var selected:bool = false

var property:ElementProperty = preload("res://addons/zylann.scatter/ui/element_property.gd").new()

# Called when the node enters the scene tree for the first time.
func _ready():
	set_color(100)
	connect("toggled",_on_element_toggled)

func _on_check_box_toggled(button_pressed):
	if button_pressed == true:
		set_color(255)
	else:
		set_color(100)
	selected = button_pressed
	emit_signal("element_select")

func _on_element_toggled(button_pressed):
#	select.visible = button_pressed
	if button_pressed:
		emit_signal("show_property",index)

func set_color(value:float):
	icon.modulate.r8 = value
	icon.modulate.g8 = value
	icon.modulate.b8 = value

func update_number(value:int):
	count.text = str(value)
