class_name RingVisuals
extends Node2D

const SLOT_DIRECTIONS: Array[Vector2] = [
	Vector2.UP,
	Vector2.LEFT,
	Vector2.DOWN,
	Vector2.RIGHT,
]

const RING_RADII := {
	&"inner": 48.0,
	&"middle": 80.0,
	&"outer": 112.0,
}

const _RING_ORDER: Array[StringName] = [&"inner", &"middle", &"outer"]
const _CONTAINER_NAMES := {
	&"inner": "Inner",
	&"middle": "Middle",
	&"outer": "Outer",
}

const _ACTIVE_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const _INACTIVE_MODULATE := Color(0.55, 0.55, 0.55, 1.0)
const _SLOT_SIZE := Vector2(28, 28)

var _controller: RingController = null
var _configured: bool = false
var _signals_connected: bool = false
var _slot_visuals: Dictionary = {} # StringName ring_id -> Array[Control]


static func get_visual_position_index(slot_index: int, active_index: int) -> int:
	return posmod(slot_index - active_index, 4)


func setup(controller: RingController) -> bool:
	if controller == null or not controller.is_configured():
		return false
	for ring_id in _RING_ORDER:
		var slots: Array[RuneData] = controller.get_ring_slots(ring_id)
		if slots.size() != 4:
			return false

	_controller = controller
	_ensure_containers()
	if not _configured:
		_build_slot_visuals()
		_configured = true
	_connect_signals_once()
	_snap_to_board_center()
	refresh_all()
	return true


func refresh_all() -> void:
	if not _configured or _controller == null or not _controller.is_configured():
		return
	for ring_id in _RING_ORDER:
		var radius: float = RING_RADII[ring_id]
		var active_index := _controller.get_active_index(ring_id)
		var visuals: Array = _slot_visuals.get(ring_id, [])
		for slot_index in range(visuals.size()):
			var visual: Control = visuals[slot_index]
			var visual_index := get_visual_position_index(slot_index, active_index)
			var dir: Vector2 = SLOT_DIRECTIONS[visual_index]
			visual.position = dir * radius - _SLOT_SIZE * 0.5
			visual.modulate = _ACTIVE_MODULATE if visual_index == 0 else _INACTIVE_MODULATE


func get_slot_visual(ring_id: StringName, slot_index: int) -> Control:
	if not _slot_visuals.has(ring_id):
		return null
	var visuals: Array = _slot_visuals[ring_id]
	if slot_index < 0 or slot_index >= visuals.size():
		return null
	return visuals[slot_index]


func _ensure_containers() -> void:
	for ring_id in _RING_ORDER:
		var container_name: String = _CONTAINER_NAMES[ring_id]
		if not has_node(container_name):
			var container := Node2D.new()
			container.name = container_name
			add_child(container)


func _build_slot_visuals() -> void:
	_slot_visuals.clear()
	for ring_id in _RING_ORDER:
		var container_name: String = _CONTAINER_NAMES[ring_id]
		var container: Node2D = get_node(container_name)
		var built: Array[Control] = []
		for i in range(4):
			var slot := ColorRect.new()
			slot.name = "%s_%d" % [container_name, i]
			slot.size = _SLOT_SIZE
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.color = Color(0.75, 0.7, 0.95, 0.9)
			container.add_child(slot)
			built.append(slot)
		_slot_visuals[ring_id] = built


func _connect_signals_once() -> void:
	if _signals_connected or _controller == null:
		return
	_controller.ring_rotated.connect(_on_ring_changed)
	_controller.ring_rotation_undone.connect(_on_ring_undone)
	_signals_connected = true


func _on_ring_changed(_ring_id: StringName, _direction: int, _active_index: int) -> void:
	refresh_all()


func _on_ring_undone(_ring_id: StringName, _active_index: int) -> void:
	refresh_all()


func _snap_to_board_center() -> void:
	var board := get_parent() as BoardManager
	if board == null:
		return
	position = Vector2(
		(board.center.x + 0.5) * BoardManager.CELL_SIZE_PX,
		(board.center.y + 0.5) * BoardManager.CELL_SIZE_PX
	)
