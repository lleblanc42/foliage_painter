@tool
extends MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass

func update_size(value:int):
	var f:float = float(value)
	f /= 100.0
	mesh.radius = f
	mesh.height = f * 2
