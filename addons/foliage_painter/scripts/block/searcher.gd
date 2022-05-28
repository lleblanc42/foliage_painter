extends RefCounted
class_name BlockSearcher

var _thread_queue: ThreadQueue
var _mtx := Mutex.new()

func _init(thread_queue: ThreadQueue):
	_thread_queue = thread_queue
	
func search_element():
	pass
