extends RefCounted
class_name BlockNode

#最大容量
var _max_items : int
#格子的大小
var _size : float
#四叉树深度
var _depth:int = 2
#节点字典
var _nodes:Array
#var _nodes:Dictionary
#数据字典
var _data:Dictionary
#父节点
var _parent_node:BlockNode
#自己的block编号
var _block_num:Vector2 = Vector2.ZERO

func _init(p:BlockNode=null,_num:Vector2=Vector2.ZERO,size: float = 8.0, max_items: int = 40,depth:int = 2):
	_parent_node = p
	_block_num = _num
	_max_items = max_items
	_size = size
	_depth = depth

func add_element(element:Node3D):
	if not _nodes.is_empty():
		var child_node = _nodes[_get_node_index(element.position)]
		child_node.add_element()
	else:
		var _key:String = element.to_string()
		_data[_key] = element
		if _data.size() >= _max_items and _depth > 0:
			_create_nodes()
			for key in _data.keys():
				var child_node = _nodes[_get_node_index(element.position)]
				child_node._data[key] = _data[key]
			_data.clear()
func clear():
	pass

#新建4个子节点
func _create_nodes():
	var half_size = _size * 0.5
	var half_max_items = int(_max_items * 0.5)
	var next_depth:int = _depth - 1
	_nodes.append(BlockNode.new(self,Vector2(0,0),half_size,half_max_items,next_depth))
	_nodes.append(BlockNode.new(self,Vector2(1,0),half_size,half_max_items,next_depth))
	_nodes.append(BlockNode.new(self,Vector2(0,1),half_size,half_max_items,next_depth))
	_nodes.append(BlockNode.new(self,Vector2(1,1),half_size,half_max_items,next_depth))
	
#获取当前节点在世界空间里的位置
func _get_position() -> Vector3:
	var position:Vector3 = Vector3.ZERO
	if _parent_node:
		position = _parent_node._get_position()
	position += Vector3(position.x + _block_num.x * _size,0.0,position.z + _block_num.y * _size)
	return position

#获取当前节点的中心点坐标
func _get_center() -> Vector3:
	var self_position:Vector3 = _get_position()
	var _center:Vector3 = Vector3(self_position.x + _size * 0.5,0.0,self_position.z + _size * 0.5)
	return _center

#左上角 0
#左下角 1
#右上角 2
#右下角 3
func _get_node_index(position:Vector3) -> int:
	var _center = _get_center()
	var index:int = 0
	if position.x >= _center.x:
		index |= 2

	if position.z >= _center.z:
		index |= 1
#	if position.x < _center.x and position.z < _center.z:
#		pass
#		#左上角
#		index = 0
#	elif position.x > _center.x and position.z < _center.z:
#		pass
#		#右上角
#		index = 1
#	elif position.x < _center.x and position.z > _center.z:
#		pass
#		#左下角
#		index = 2
#	elif position.x > _center.x and position.z > _center.z:
#		pass
#		#右下角
#		index = 3
	return 0

#检查节点是否在刷子范围之内
func check_node_cover(brush_pos:Vector3,radius:float) -> bool:
	var position:Vector3 = _get_position()
	#左上角
	var left_top:Vector3 = position
	#左下角
	var left_bottom:Vector3 = Vector3(position.x,position.y,position.z + _size)
	#右上角
	var right_top:Vector3 = Vector3(position.x + _size,position.y,position.z)
	#右下角
	var right_bottom:Vector3 = Vector3(position.x + _size,position.y,position.z + _size)
	
	var is_cover:bool = _check_radius(brush_pos,left_top,radius)
	if not is_cover:
		is_cover = _check_radius(brush_pos,left_bottom,radius)
	if not is_cover:
		is_cover = _check_radius(brush_pos,right_top,radius)
	if not is_cover:
		is_cover = _check_radius(brush_pos,right_bottom,radius)
	
	return is_cover

#检查两点间的距离是否小于给定值
func _check_radius(brush_pos:Vector3,position:Vector3,radius:float) -> bool:
	var dis:float = position.distance_to(brush_pos)
	if dis < radius:
		return true
	return false
	
#获得节点内所有在刷子范围内的物体
func get_all_cover_element(brush_pos:Vector3,radius:float):
	var all_elements:Array = []
	if not _nodes.is_empty():
		pass
	else:
		pass
