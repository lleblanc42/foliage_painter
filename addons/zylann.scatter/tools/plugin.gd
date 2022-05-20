@tool
extends EditorPlugin

enum MODE {
	SELECT_MODE = 0,
	FOLIAGE_MODE = 1
}

const FOLIAGE_NAME:String = "Foliage3D"
const Foliage3D = preload("res://addons/zylann.scatter/foliage3d.gd")
const PaletteScene = preload("res://addons/zylann.scatter/tools/palette.tscn")
#左侧素材列表
var _palette:Palette = preload("res://addons/zylann.scatter/tools/palette.tscn").instantiate()
#顶部模式选择UI
var _topui = preload("res://addons/zylann.scatter/tools/topui.tscn").instantiate()
#const Palette = preload("./palette.gd")
const Util = preload("../util/util.gd")
const Logger = preload("../util/logger.gd")

const ACTION_PAINT = 0
const ACTION_ERASE = 1

#模式 0选择 1植物
var mode:int = 0

#绘制根节点
var foliage : Foliage3D
var _selected_patterns := []
var _mouse_position := Vector2()
var _editor_camera : Camera3D
var _collision_mask := 1
var _placed_instances = []
var _removed_instances = []
var _disable_undo := false
var _pattern_margin := 0.0
var _logger = Logger.get_for(self)
var _current_action := -1
var _cmd_pending_action := false
var _error_dialog = null


static func get_icon(name):
	return load("res://addons/zylann.scatter/tools/icons/icon_" + name + ".svg")


func _enter_tree():
	_logger.debug("Scatter plugin Enter tree")
	print("Scatter plugin Enter tree")
	
	_topui.connect("toggle_mode",_on_toggle_mode)
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,_topui)
	
	# The class is globally named but still need to register it just so the node creation dialog gets it
	# https://github.com/godotengine/godot/issues/30048
	add_custom_type("Foliage3D", "Node3D", Foliage3D, get_icon("scatter3d_node"))
	
	var base_control = get_editor_interface().get_base_control()

	_palette.connect("patterns_selected", _on_Palette_patterns_selected)
	_palette.connect("pattern_added", _on_Palette_pattern_added)
	_palette.connect("patterns_removed", _on_Palette_patterns_removed)
	_palette.hide()
	add_control_to_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT,_palette)
	_palette.set_preview_provider(get_editor_interface().get_resource_previewer())
	_palette.call_deferred("setup_dialogs", base_control)

	_error_dialog = AcceptDialog.new()
	_error_dialog.size = Vector2(300, 200)
#	_error_dialog.rect_min_size = Vector2(300, 200)
	_error_dialog.hide()
	_error_dialog.title = "Error"
	base_control.add_child(_error_dialog)

func _exit_tree():
	_logger.debug("Scatter plugin Exit tree")
	_edit(null)

	remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU,_topui)
	remove_custom_type("Scatter3D")
	remove_control_from_container(CustomControlContainer.CONTAINER_SPATIAL_EDITOR_SIDE_LEFT,_palette)
	
	if _palette != null:
		_palette.queue_free()
		_palette = null

	if _palette != null:
		_error_dialog.queue_free()
		_error_dialog = null


func _handles(obj):
	return obj != null and obj is Foliage3D


func _edit(obj):
	foliage = obj
	if foliage:
		var patterns = foliage.get_patterns()
		_palette.load_patterns(patterns)
		set_physics_process(true)
	else:
		set_physics_process(false)


func _make_visible(visible):
	_palette.set_visible(visible)
	# TODO Workaround https://github.com/godotengine/godot/issues/6459
	# When the user selects another node, I want the plugin to release its references.
	if not visible:
		_edit(null)

func _forward_3d_gui_input(p_camera:Camera3D, p_event:InputEvent):
	
	if foliage == null:
		return false

	var captured_event = false
	if p_event is InputEventMouseButton:
#		var mb:InputEventMouseButton = p_event as InputEventMouseButton

		if p_event.button_index == MOUSE_BUTTON_LEFT:# or p_event.button_index == MOUSE_BUTTON_RIGHT:
			# Need to check modifiers before capturing the event,
			# because they are used in navigation schemes
			if (not p_event.ctrl_pressed) and (not p_event.alt_pressed):# and mb.button_index == BUTTON_LEFT:
				if p_event.pressed:
					match p_event.button_index:
						MOUSE_BUTTON_LEFT:
							_current_action = ACTION_PAINT
						MOUSE_BUTTON_RIGHT:
							_current_action = ACTION_ERASE
					_cmd_pending_action = true

				captured_event = true

				if p_event.pressed == false:
					# Just finished painting gesture
					_on_action_completed(_current_action)

	elif p_event is InputEventMouseMotion:
#		var mm = p_event
		var mouse_position = p_event.position

		# Need to do an extra conversion in case the editor viewport is in half-resolution mode
		var viewport = p_camera.get_viewport()
		var viewport_container:SubViewportContainer = viewport.get_parent()
		var screen_position = mouse_position * Vector2(viewport.size) / viewport_container.size

		_mouse_position = screen_position
		# Trigger action only if these buttons are held
		_cmd_pending_action = p_event.button_mask & (MOUSE_BUTTON_MASK_LEFT | MOUSE_BUTTON_MASK_RIGHT)

	_editor_camera = p_camera
	return captured_event


func _physics_process(_unused_delta):
	if _editor_camera == null:
		return
	if not is_instance_valid(_editor_camera):
		_editor_camera = null
		return
	if foliage == null:
		return

	if _cmd_pending_action:
		# Consume
		_cmd_pending_action = false

		var ray_origin = _editor_camera.project_ray_origin(_mouse_position)
		var ray_dir = _editor_camera.project_ray_normal(_mouse_position)
		var ray_distance = _editor_camera.far

#		print("ray_origin: ",ray_origin)
#		print("ray_dir: ",ray_dir)
#		print("ray_distance: ",ray_distance)
#		print("to" ,ray_origin + ray_dir * ray_distance)

		match _current_action:
			ACTION_PAINT:
				_paint(ray_origin, ray_origin + ray_dir * ray_distance)
			ACTION_ERASE:
				_erase(ray_origin, ray_dir)


func _paint(ray_origin: Vector3, ray_end: Vector3):
	if len(_selected_patterns) == 0:
		return

	var space_state =  get_viewport().world_3d.direct_space_state
	var pt:PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	pt.from = ray_origin
	pt.to = ray_origin + ray_end
	pt.exclude = []
	pt.collision_mask = _collision_mask
	var hit = space_state.intersect_ray(pt)
	
	if hit.is_empty():
		return

	var hit_instance_root
	# Collider can be null if the hit is on something that has no associated node
	if hit.collider != null:
		hit_instance_root = Util.get_instance_root(hit.collider)

	if hit.collider == null or not (hit_instance_root.get_parent() is Foliage3D):
		var pos = hit.position
		# Not accurate, you might still paint stuff too close to others,
		# but should be good enough and cheap
		var too_close = false
		if len(_placed_instances) != 0:
			var last_placed_transform := (_placed_instances[-1] as Node3D).global_transform
			var margin = _pattern_margin + _palette.get_configured_margin()
			if last_placed_transform.origin.distance_to(pos) < margin:
				too_close = true

		if not too_close:
			var instance:MeshInstance3D = _create_pattern_instance()
			var path = instance.get_meta("path")
			
			#get scene path hash code
			var base_name = path.get_file().get_basename()
			var pash_hash:int = path.hash()
			var layer_name:String = "%s_%d" % [base_name,pash_hash]
			print("layer_name: ",layer_name)
			var layer = foliage.get_node_or_null(layer_name)
			print("layer: ",layer)
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
#			foliage.add_child(instance)
			instance.owner = get_editor_interface().get_edited_scene_root()
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
			_removed_instances.append(instance)


func _on_action_completed(action: int):
	if action == ACTION_PAINT:
		if len(_placed_instances) == 0:
			return
		# TODO This will creep memory until the scene is closed...
		# Because in Godot, undo/redo of node creation/deletion is done by NOT deleting them.
		# To stay in line with this, I have to do the same...
		var ur = get_undo_redo()
		ur.create_action("Paint scenes")
		for instance in _placed_instances:
			# This is what allows nodes to be freed
			ur.add_do_reference(instance)
		_disable_undo = true
		ur.add_do_method(self, "_redo_paint", foliage.get_path(), _placed_instances.duplicate(false))
		ur.add_undo_method(self, "_undo_paint", foliage.get_path(), _placed_instances.duplicate(false))
		ur.commit_action()
		_disable_undo = false
		_placed_instances.clear()

	elif action == ACTION_ERASE:
		if len(_removed_instances) == 0:
			return
		var ur = get_undo_redo()
		ur.create_action("Erase painted scenes")
		for instance in _removed_instances:
			ur.add_undo_reference(instance)
		_disable_undo = true
		ur.add_do_method(self, "_redo_erase", foliage.get_path(), _removed_instances.duplicate(false))
		ur.add_undo_method(self, "_undo_erase", foliage.get_path(), _removed_instances.duplicate(false))
		ur.commit_action()
		_disable_undo = false
		_removed_instances.clear()


#func resnap_instances():
#	pass


func _redo_paint(parent_path, instances_data):
	if _disable_undo:
		return
	var parent = get_node(parent_path)
	for instance in instances_data:
		parent.add_child(instance)


func _undo_paint(parent_path, instances_data):
	if _disable_undo:
		return
	var parent = get_node(parent_path)
	for instance in instances_data:
		parent.remove_child(instance)


func _redo_erase(parent_path, instances_data):
	if _disable_undo:
		return
	var parent = get_node(parent_path)
	for instance in instances_data:
		instance.get_parent().remove_child(instance)


func _undo_erase(parent_path, instances_data):
	if _disable_undo:
		return
	var parent = get_node(parent_path)
	for instance in instances_data:
		parent.add_child(instance)


# Goes up the tree from the given node and finds the first Scatter layer,
# then return the immediate child of it from which the node is child of
static func get_scatter_child_instance(node, scatter_root):
	var parent = node
	while parent != null:
		parent = node.get_parent()
		if parent != null and parent == scatter_root:
			return node
		node = parent
	return null


func _set_selected_patterns(patterns):
	if _selected_patterns != patterns:
		_selected_patterns = patterns
		var largest_aabb = AABB()
		for pattern in patterns:
			var temp = pattern.instantiate()
			# TODO This causes errors because of accessing `global_transform` outside the tree... Oo
			# See https://github.com/godotengine/godot/issues/30445
			largest_aabb = largest_aabb.merge(Util.get_scene_aabb(temp))
			temp.free()
		_pattern_margin = largest_aabb.size.length() * 0.4
		_logger.debug(str("Pattern margin is ", _pattern_margin))


func _create_pattern_instance():
	var rand:int = randi_range(0,_selected_patterns.size() - 1)
	var ins = _selected_patterns[rand].instantiate()
	var path = _selected_patterns[rand].get_meta("path")
	ins.set_meta("path",path)
	return ins


func _on_Palette_patterns_selected(pattern_paths):
	var scenes = []
	for file in pattern_paths:
		var packet = load(file)
		packet.set_meta("path",file)
		scenes.append(packet)
	_set_selected_patterns(scenes)


func _on_Palette_pattern_added(path):
	if not _verify_scene(path):
		return
	# TODO Duh, may not work if the file was moved or renamed... I'm tired of this
	var ur = get_undo_redo()
	ur.create_action("Add scatter pattern")
	ur.add_do_method(self, "_add_pattern", path)
	ur.add_undo_method(self, "_remove_pattern", path)
	ur.commit_action()


func _on_Palette_patterns_removed(paths):
	var ur = get_undo_redo()
	ur.create_action("Remove scatter pattern")
	for path in paths:
		ur.add_do_method(self, "_remove_pattern", path)
		ur.add_undo_method(self, "_add_pattern", path)
	ur.commit_action()


func _add_pattern(path):
	_logger.debug(str("Adding pattern ", path))
	foliage.add_pattern(path)
	_palette.add_pattern(path)


func _remove_pattern(path):
	_logger.debug(str("Removing pattern ", path))
	foliage.remove_pattern(path)
	_palette.remove_pattern(path)


func _verify_scene(fpath):
	# Check it can be loaded
	var scene = load(fpath)
	if scene == null:
		_show_error(tr("Could not load the scene. See the console for more info."))
		return false

	# Check it's not already in the list
	if foliage.has_pattern(fpath):
		_palette.select_pattern(fpath)
		_show_error(tr("The selected scene is already in the palette"))
		return false

	# Check it's not the current scene itself
	if Util.is_self_or_parent_scene(fpath, foliage):
		_show_error("The selected scene can't be added recursively")
		return false

	# Check it inherits Node3D
#	var scene_state = scene.get_state()
#	var root_type = scene_state.get_node_type(0)
	# Aaaah screw this
	var scene_instance = scene.instantiate()
	if not (scene_instance is Node3D):
		_show_error(tr("The selected scene is not a Node3D, it can't be painted in a 3D scene."))
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
	pass

func foliage_mode():
	#获取主场景
	var root = get_editor_interface().get_edited_scene_root()
	
	var has_foliage_node:bool = false
	for node in root.get_children():
		if(node.name == FOLIAGE_NAME):
			has_foliage_node = true
			break
	if !has_foliage_node:
		print("没有Foliage3D")
		foliage = Foliage3D.new()
		foliage.name = FOLIAGE_NAME
		root.add_child(foliage)
		foliage.owner = root

func _show_error(msg):
	_error_dialog.dialog_text = msg
	_error_dialog.popup_centered_minsize()

