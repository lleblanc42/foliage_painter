@tool
extends Control

signal toggle_mode(int)

var select_mode:int = 0

func _on_mode_toggled(button_pressed, id):
	if select_mode == id:
		return
	select_mode = id
	emit_signal("toggle_mode",id)
