class_name Pool
## Object pool for frequently spawned 3D models (gems, orbs, drones).
## Reusing nodes avoids allocation spikes in the hot loop.

var _model: String
var _parent: Node
var _free: Array[Node3D] = []
var _setup: Callable


func _init(model_name: String, parent: Node, setup := Callable()) -> void:
	_model = model_name
	_parent = parent
	_setup = setup


func prewarm(count: int) -> void:
	for i in count:
		release(_make())


func acquire() -> Node3D:
	var n: Node3D = _free.pop_back() if not _free.is_empty() else _make()
	n.visible = true
	n.scale = Vector3.ONE
	n.rotation = Vector3.ZERO
	return n


func release(n: Node3D) -> void:
	n.visible = false
	_free.append(n)


## Call after moving a reused node to a new spot so it doesn't interpolate there.
static func teleported(n: Node3D) -> void:
	if n.is_inside_tree():
		n.reset_physics_interpolation()


func _make() -> Node3D:
	var n := Stage.model(_model)
	_parent.add_child(n)
	if _setup.is_valid():
		_setup.call(n)
	return n
