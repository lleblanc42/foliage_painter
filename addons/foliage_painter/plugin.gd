@tool
extends EditorPlugin

enum MODE {
	SELECT_MODE = 0,
	FOLIAGE_MODE = 1
}

const FOLIAGE_NAME:String = "Foliage3D"
const BRUSH_NAME:String = "Brush"
const BLOCK_NAME:String = "Block"
const Foliage3D = preload("./ui/foliage3d.gd")
const PaletteScene = preload("./ui/palette.tscn")
#const Octree = preload("./scripts/octree.gd")
var Brush3D = preload("./mesh/brush.tscn")
#左侧素材列表
var _palette:Palette = preload("./ui/palette.tscn").instantiate()
#顶部模式选择UI
var _topui = preload("./ui/topui.tscn").instantiate()

#绘制根节点
var foliage : Foliage3D
var brush:MeshInstance3D
#分块计算逻辑
var block:Block = null
var _selected_elements := []
var _mouse_position := Vector2()
#var _editor_camera : Camera3D
var _collision_mask := 1
var _placed_instances = []
#var _removed_instances = []
#var _disable_undo := false
var _current_action := -1
var _cmd_pending_action := false
#可以绘制
var start_paint:bool = true

var mouse_left_pressed:bool = false
var mouse_right_pressed:bool = false


static func get_icon(name):
	return load("res://addons/foliage_painter/icons/icon_" + name + ".svg")


func _enter_tree():
	print("Scatter plugin Enter tree")
	
	set_physics_process(false)
	
	_topui.connect("toggle_mode",_on_toggle_mode)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,_topui)
	
	add_custom_type("Foliage3D", "Node3D", Foliage3D, get_icon("scatter3d_node"))
	
	var base_control = get_editor_interface().get_base_control()

	_palette.connect("elements_selected", _on_Palette_element_selected)
	_palette.connect("element_added", _on_Palette_element_added)
	_palette.connect("elements_removed", _on_Palette_patterns_removed)
	_palette.connect("brush_size_changed", _on_Brush_size_changed)
	_palette.hide()
	add_control_to_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT,_palette)
	_palette.set_preview_provider(get_editor_interface().get_resource_previewer())
	_palette.call_deferred("setup_dialogs", base_control)
	
	#初始化分块计算逻辑
	init_block()
	show_brush(false)
	
	set_input_event_forwarding_always_enabled()

func _exit_tree():

	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,_topui)
	remove_custom_type("Scatter3D")
	remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT,_palette)
	
	if _palette != null:
		_palette.queue_free()
		_palette = null

func _handles(object):
	pass

func _edit(obj):
	pass

func _forward_3d_gui_input(p_camera:Camera3D, p_event:InputEvent):
	if _palette.mode == MODE.SELECT_MODE:
		return false
	if foliage == null:
		return false
	if _selected_elements.size() == 0:
		show_brush(false)
		return false
	
	if mouse_right_pressed:
		show_brush(false)
		if not (p_event is InputEventMouseButton and not p_event.pressed and p_event.button_index == MOUSE_BUTTON_RIGHT):
			return false
	elif mouse_right_pressed == false and brush.visible == false:
		show_brush(true)

	#射线检测
	if p_event is InputEventMouseMotion:
		var mouse_position = p_event.position
		var viewport = p_camera.get_viewport()
		var viewport_container:SubViewportContainer = viewport.get_parent()
		var screen_position = mouse_position * Vector2(viewport.size) / viewport_container.size
		_mouse_position = screen_position

	var ray_origin = p_camera.project_ray_origin(_mouse_position)
	var ray_dir = p_camera.project_ray_normal(_mouse_position)
	var ray_distance = p_camera.far

	var hit:Dictionary = ray_cast(ray_origin, ray_origin + ray_dir * ray_distance)

	var captured_event = false
	#鼠标按钮判定
	if p_event is InputEventMouseButton:
		if p_event.pressed:
			if p_event.button_index == MOUSE_BUTTON_LEFT:
				mouse_left_pressed = true
				captured_event = true
			elif p_event.button_index == MOUSE_BUTTON_RIGHT:
				mouse_right_pressed = true
		else:
			if p_event.button_index == MOUSE_BUTTON_LEFT:
				mouse_left_pressed = false
			elif p_event.button_index == MOUSE_BUTTON_RIGHT:
				mouse_right_pressed = false
	
	if _palette.tool_mode == _palette.SINGLE:
		_paint(hit)
	else:
		start_paint = true
				
	#如果鼠标左键按下
	if p_event is InputEventMouseMotion and mouse_left_pressed and start_paint:
		if _palette.tool_mode == _palette.PAINT:
			if not hit.is_empty():
				start_paint = false
				_paint(hit)
		elif _palette.tool_mode == _palette.ERASE:
			pass
#			_erase(ray_origin, ray_dir)
	
	return captured_event

func ray_cast(ray_origin: Vector3, ray_end: Vector3) -> Dictionary:
	var space_state =  get_viewport().world_3d.direct_space_state
	var pt:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	pt.from = ray_origin
	pt.to = ray_origin + ray_end
	pt.exclude = []
	pt.collision_mask = _collision_mask
	var hit = space_state.intersect_ray(pt)
	
	if hit.is_empty():
		return hit
	
	var hit_instance_root
	# Collider can be null if the hit is on something that has no associated node
	if hit.collider != null:
		hit_instance_root = FoliagePrinterUtil.get_instance_root(hit.collider)
	
	if hit.collider == null or not (hit_instance_root.get_parent() is Foliage3D):
		var pos = hit.position
		brush.position = hit.position
	return hit

func _paint(hit:Dictionary):
	if len(_selected_elements) == 0:
		return

#	var space_state =  get_viewport().world_3d.direct_space_state
#	var pt:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
#	pt.from = ray_origin
#	pt.to = ray_origin + ray_end
#	pt.exclude = []
#	pt.collision_mask = _collision_mask
#	var hit = space_state.intersect_ray(pt)
#
#	if hit.is_empty():
#		return

	var hit_instance_root
	# Collider can be null if the hit is on something that has no associated node
	if hit.collider != null:
		hit_instance_root = FoliagePrinterUtil.get_instance_root(hit.collider)

	if hit.collider == null or not (hit_instance_root.get_parent() is Foliage3D):
		var pos = hit.position
		brush.position = hit.position
		# Not accurate, you might still paint stuff too close to others,
		# but should be good enough and cheap
		var too_close = false
		if _palette.mode != MODE.SELECT_MODE and  len(_placed_instances) != 0:
			var node:Node3D = _placed_instances[-1]
			var last_path = node.get_meta("path")
			var last_property:ElementProperty = _palette.get_element_property(last_path)
			var last_placed_transform := node.global_transform
			if last_placed_transform.origin.distance_to(pos) < last_property.radius:
				too_close = true
				print("too_close: ",too_close)

		if not too_close:
			var instance:MeshInstance3D = _create_element_instance()
			var path = instance.get_meta("path")

			var layer_name:String = get_layer_name(path)
			var layer = foliage.get_node_or_null(layer_name)
			
			if layer == null:
				print("添加Layer")
				layer = Node3D.new()
				layer.name = layer_name
				foliage.add_child(layer)
				layer.owner = get_editor_interface().get_edited_scene_root()

			#user property
			var property:ElementProperty = _palette.get_element_property(path)
			#random y offset from min ~ max
			var yOffset:float = randf_range(property.yOffsetMin,property.yOffsetMax)
			#10 times smaller,so -1000 to 1000 is -10 meter to 10 meter
			yOffset /= 10
			instance.position = pos + Vector3(0,yOffset,0)
			#random roate from min ~ max
			var angle:float = randf_range(property.rotateMin,property.rotateMax)
			var rad:float = deg2rad(angle)
			instance.rotate_y(rad)
			#random scale from min ~ max
			var s:float = randf_range(property.scaleMin,property.scaleMax)
			instance.scale = Vector3(s,s,s)
			
			layer.add_child(instance)
#			instance.name = "%s_%d" % [base_name,layer.get_child_count()]
	#			foliage.add_child(instance)
			instance.owner = get_editor_interface().get_edited_scene_root()
			var count = layer.get_child_count()
			_palette.update_element_number(path,count)
			_placed_instances.append(instance)


func _erase(ray_origin: Vector3, ray_dir: Vector3):
#	var time_before := Time.get_ticks_usec()
	var hits := RenderingServer.instances_cull_ray(ray_origin, ray_dir, foliage.get_world_3d().scenario)
#	print("hits: ",hits)
	if len(hits) > 0:
		var instance = null
		for hit_object_id in hits:
			var hit = instance_from_id(hit_object_id)
#			print("hit: ",hit," hit.name: ",hit.name)
			if hit is Node3D:
				instance = get_scatter_child_instance(hit, foliage)
				if instance != null:
					break

#		print("Hits: ", len(hits), ", instance: ", instance)
		if instance != null:
			assert(instance.get_parent() == foliage)
			instance.get_parent().remove_child(instance)
#			_removed_instances.append(instance)


#func _on_action_completed(action: int):
#	if action == ACTION_PAINT:
#		pass
#		if len(_placed_instances) == 0:
#			return
		# TODO This will creep memory until the scene is closed...
		# Because in Godot, undo/redo of node creation/deletion is done by NOT deleting them.
		# To stay in line with this, I have to do the same...
#		var ur = get_undo_redo()
#		ur.create_action("Paint scenes")
#		for instance in _placed_instances:
#			# This is what allows nodes to be freed
#			ur.add_do_reference(instance)
#		_disable_undo = true
#		ur.add_do_method(self, "_redo_paint", foliage.get_path(), _placed_instances.duplicate(false))
#		ur.add_undo_method(self, "_undo_paint", foliage.get_path(), _placed_instances.duplicate(false))
#		ur.commit_action()
#		_disable_undo = false
#		_placed_instances.clear()

#	elif action == ACTION_ERASE:
#		pass
#		if len(_removed_instances) == 0:
#			return
#		var ur = get_undo_redo()
#		ur.create_action("Erase painted scenes")
#		for instance in _removed_instances:
#			ur.add_undo_reference(instance)
#		_disable_undo = true
#		ur.add_do_method(self, "_redo_erase", foliage.get_path(), _removed_instances.duplicate(false))
#		ur.add_undo_method(self, "_undo_erase", foliage.get_path(), _removed_instances.duplicate(false))
#		ur.commit_action()
#		_disable_undo = false
#		_removed_instances.clear()



#func _redo_paint(parent_path, instances_data):
#	if _disable_undo:
#		return
#	var parent = get_node(parent_path)
#	for instance in instances_data:
#		parent.add_child(instance)
#
#
#func _undo_paint(parent_path, instances_data):
#	if _disable_undo:
#		return
#	var parent = get_node(parent_path)
#	for instance in instances_data:
#		parent.remove_child(instance)


#func _redo_erase(parent_path, instances_data):
#	if _disable_undo:
#		return
#	var parent = get_node(parent_path)
#	for instance in instances_data:
#		instance.get_parent().remove_child(instance)
#
#
#func _undo_erase(parent_path, instances_data):
#	if _disable_undo:
#		return
#	var parent = get_node(parent_path)
#	for instance in instances_data:
#		parent.add_child(instance)

func init_block():
	block = Block.new(8,40,1)
	if foliage:
		block.update(foliage)

# Goes up the tree from the given node and finds the first Scatter layer,
# then return the immediate child of it from which the node is child of
func get_scatter_child_instance(node, scatter_root):
	var parent = node
	while parent != null:
		parent = node.get_parent()
		if parent != null and parent == scatter_root:
			return node
		node = parent
	return null


func _set_selected_elements(patterns):
	if _selected_elements != patterns:
		_selected_elements = patterns
		var largest_aabb = AABB()
		for pattern in patterns:
			var temp = pattern.instantiate()
			# TODO This causes errors because of accessing `global_transform` outside the tree... Oo
			# See https://github.com/godotengine/godot/issues/30445
			largest_aabb = largest_aabb.merge(FoliagePrinterUtil.get_scene_aabb(temp))
			temp.free()
#		_pattern_margin = largest_aabb.size.length() * 0.4


func _create_element_instance():
	var rand:int = randi_range(0,_selected_elements.size() - 1)
	var ins = _selected_elements[rand].instantiate()
	var path = _selected_elements[rand].get_meta("path")
	ins.set_meta("path",path)
	return ins


func _on_Palette_element_selected(pattern_paths):
	var scenes = []
	for file in pattern_paths:
		var packet = load(file)
		packet.set_meta("path",file)
		scenes.append(packet)
	_set_selected_elements(scenes)


func _on_Palette_element_added(path):
	if not _verify_element(path):
		return
	_add_element(path)
	# TODO Duh, may not work if the file was moved or renamed... I'm tired of this
#	var ur = get_undo_redo()
#	ur.create_action("Add scatter pattern")
#	ur.add_do_method(self, "_add_pattern", path)
#	ur.add_undo_method(self, "_remove_pattern", path)
#	ur.commit_action()


func _on_Palette_patterns_removed(paths):
	for path in paths:
		_remove_element(path)
#	var ur = get_undo_redo()
#	ur.create_action("Remove scatter pattern")
#	for path in paths:
#		ur.add_do_method(self, "_remove_pattern", path)
#		ur.add_undo_method(self, "_add_pattern", path)
#	ur.commit_action()


func _add_element(path):
	foliage.add_pattern(path)
	_palette.add_pattern(path)


func _remove_element(path):
	foliage.remove_element(path)
	_palette.remove_element(path)

func _on_Brush_size_changed():
	pass
	brush.update_size(_palette.brushSize.value)

func _verify_element(fpath):
	# Check it can be loaded
	var scene = load(fpath)
	if scene == null:
		print("Could not load the scene. See the console for more info.")
		return false

	# Check it's not already in the list
	if foliage.has_element(fpath):
		_palette.select_element(fpath)
		print("The selected scene is already in the palette")
		return false

	# Check it's not the current scene itself
	if FoliagePrinterUtil.is_self_or_parent_scene(fpath, foliage):
		print("The selected scene can't be added recursively")
		return false

	# Check it inherits Node3D
#	var scene_state = scene.get_state()
#	var root_type = scene_state.get_node_type(0)
	# Aaaah screw this
	var scene_instance = scene.instantiate()
	if not (scene_instance is Node3D):
		print("The selected scene is not a Node3D, it can't be painted in a 3D scene.")
		scene_instance.free()
		return false
	scene_instance.free()

	return true

#切换模式
func _on_toggle_mode(id):
	_palette.mode = id
	match id:
		MODE.SELECT_MODE:
			select_mode()
		MODE.FOLIAGE_MODE:
			foliage_mode()

func select_mode():
#	set_physics_process(false)
	_palette.set_visible(false)
	show_brush(false)

func foliage_mode():
	#获取主场景
	var root = get_editor_interface().get_edited_scene_root()
	var f = root.get_node_or_null(FOLIAGE_NAME)
	#植被根节点
	if f == null:
		print("没有Foliage3D")
		foliage = Foliage3D.new()
		foliage.name = FOLIAGE_NAME
		root.add_child(foliage)
		foliage.owner = root
	else:
		foliage = f
	#刷子
	var b = foliage.get_node_or_null(BRUSH_NAME)
	if b == null:
		print("没有Brush")
		brush = Brush3D.instantiate()
		brush.name = BRUSH_NAME
		foliage.add_child(brush)
		brush.owner = root
	else:
		brush = b
	brush.update_size(_palette.brushSize.value)
	
	readd_element()
	_palette.set_visible(true)
	show_brush(true)
#	set_physics_process(true)

#切换工具时重新给面板赋值
func readd_element():
	var element_list:Array[Dictionary] = []
	var elements = foliage.get_elements()
	for scene in elements:
		var dic:Dictionary = Dictionary()
		dic["path"] = scene.resource_path
		var select:bool = false
		for s in _selected_elements:
			if s.get_meta("path") == scene.resource_path:
				select = true
				break
		dic["selected"] = select
		var layer = get_layer(scene.resource_path)
#		var base_name = scene.resource_path.get_file().get_basename()
#		var pash_hash:int = scene.resource_path.hash()
#		var layer_name:String = "layer_%s_%d" % [base_name,pash_hash]
#		var layer = foliage.get_node_or_null(layer_name)
		var num:int = 0
		if layer:
			num = layer.get_child_count()
		dic["number"] = num
		element_list.append(dic)
	_palette.load_elements(element_list)

#显示刷子
func show_brush(value:bool):
	if brush:
		brush.visible = value

#根据地址获取layer name
func get_layer_name(path:String) -> String:
	var base_name = path.get_basename()
	var pash_hash:int = path.hash()
	var layer_name:String = "layer_%s_%d" % [base_name,pash_hash]
	return layer_name

#根据地址获取layer
func get_layer(path:String) -> Node3D:
	var layer_name:String = get_layer_name(path)
	var layer = foliage.get_node_or_null(layer_name)
	return layer
