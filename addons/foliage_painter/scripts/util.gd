@tool
class_name FoliagePainterUtil

#static func get_scene_aabb(node, aabb=AABB(), parent_transform=Transform3D()):
#	if not node.visible:
#		return aabb
#	var gtrans := Transform3D()
#	if node is Node3D:
#		# We cannot use `global_transform` because the node might not be in the scene tree.
#		# If we still use it, Godot will print warnings.
#		gtrans = parent_transform * node.transform
#	if node is VisualInstance3D:
#		var node_aabb = gtrans * node.get_aabb()
#		#var node_aabb = gtrans.xform(node.get_aabb())
#		if aabb == AABB():
#			aabb = node_aabb
#		else:
#			aabb = aabb.merge(node_aabb)
#	for i in node.get_child_count():
#		aabb = get_scene_aabb(node.get_child(i), aabb, gtrans)
#	return aabb


static func get_instance_root(node):
	# TODO Could use `owner`?
	while node != null and node.scene_file_path == "":
		node = node.get_parent()
	return node


# static func get_node_in_parents(node, klass):
# 	while node != null:
# 		node = node.get_parent()
# 		if node != null and node is klass:
# 			return node
# 	return null


static func is_self_or_parent_scene(fpath, node):
	while node != null:
		if node.scene_file_path == fpath:
			return true
		node = node.get_parent()
	return false

#获取地址列表
static func get_path_list(l:Array) -> Array[String]:
	var path_list:Array[String] = []
	for element in l:
		var path:String = element.get_meta("path")
		path_list.append(path)
	return path_list

#根据射线获得与地形相交的点坐标
static func _get_raycast_position(space_state:PhysicsDirectSpaceState3D,position:Vector3,radius:float) -> Dictionary:
#	var radius:float = brush.get_radius()
#	var space_state =  get_viewport().world_3d.direct_space_state
	var pt:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	pt.from = Vector3(position.x,position.y + radius,position.z)
	pt.to = Vector3(position.x,position.y - radius,position.z)
	var hits = space_state.intersect_ray(pt)
	
	if hits.is_empty():
		print("什么都没碰到")
		return Dictionary()
	
	var hit_instance_root
	if hits.collider != null:
		hit_instance_root = get_instance_root(hits.collider)
	
	if hits.collider == null or not (hit_instance_root.has_meta("path")):
		return hits
#	print("hits: ",hits)
	return Dictionary()

#生成点-方法1
static func generatePointInCycle1(space_state:PhysicsDirectSpaceState3D,point_num:int,position:Vector3,radius:float,min_distance:float) -> Array:
	var points:Array[Vector3] = []
	var x:float
	var z:float
	for i in range(1,point_num + 1):
		while true:
			x = randf_range(-radius,radius)
			z = randf_range(-radius,radius)
			if pow(x,2) + pow(z,2) < pow(radius,2):
				var pos:Vector3 = Vector3(x + position.x,position.y,z + position.z)
				var hits:Dictionary = _get_raycast_position(space_state,pos,radius)
				var licit:bool = _check_distance(points,pos,min_distance)
				if not hits.is_empty() and licit == true:
					points.append(hits.position)
#				var licit:bool = _check_distance(points,pos,min_distance)
#				if licit:
#					points.append(hits.position)
				break
	return points
	
#生成点-方法2
static func generatePointInCycle2(space_state:PhysicsDirectSpaceState3D,point_num:int,position:Vector3,radius:float) -> Array:
	var points:Array[Vector3] = []
	var x:float
	var z:float
	var rand:float
	var r:float
	for i in range(1,point_num + 1):
		rand = randf() * 2 * PI
		r = randf_range(0,radius)
		x = sin(rand) * pow(r,0.5)
		z = cos(rand) * pow(r,0.5)
		var pos:Vector3 = Vector3(x + position.x,position.y,z + position.z)
		var hits:Dictionary = _get_raycast_position(space_state,pos,radius)
		if not hits.is_empty():
			points.append(hits.position)
	return points

static func _check_distance(list:Array,position:Vector3,min_distance:float) -> bool:
	var b:bool = true
	for pos in list:
		var dis:float = pos.distance_to(position)
		if dis < min_distance:
			b = false
			break
	return b
