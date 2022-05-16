@tool
extends Control

var select_icon = preload("res://addons/zylann.scatter/tools/icons/select.png")
var foliage_icon = preload("res://addons/zylann.scatter/tools/icons/foliage.png")

@onready var menuBtn:MenuButton = $MenuButton

var select_index:int = 0

func _ready():
	menuBtn.get_popup().connect("id_pressed",on_item_press)

func _enter_tree():
	pass
#	$MenuButton.connect("id_pressed",on_item_press)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func on_item_press(id):
	if select_index == id:
		return
	select_index = id
	match id:
		0:
			menuBtn.text = "Select Mode"
			menuBtn.icon = select_icon
		1:
			menuBtn.text = "Foliage Mode"
			menuBtn.icon = foliage_icon
	



func _on_topui_tree_exiting():
	pass # Replace with function body.
	menuBtn.get_popup().disconnect("id_pressed",on_item_press)
