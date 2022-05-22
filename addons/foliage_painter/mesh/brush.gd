@tool
extends MeshInstance3D

func update_size(value:int):
	var f:float = float(value)
	f /= 100.0
	mesh.radius = f
	mesh.height = f * 2
