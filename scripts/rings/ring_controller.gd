class_name RingController
extends Node

const MAX_ROTATIONS: int = 2
const RING_INNER := &"inner"
const RING_MIDDLE := &"middle"
const RING_OUTER := &"outer"

signal ring_rotated(ring_id: StringName, direction: int, active_index: int)
signal ring_rotation_undone(ring_id: StringName, active_index: int)
signal active_runes_changed(element: RuneData, shape: RuneData, modifier: RuneData)
signal rotations_changed(remaining: int)

var _configured: bool = false
var remaining_rotations: int = 0
var _inner: RingModel = null
var _middle: RingModel = null
var _outer: RingModel = null
var _undo_stack: Array = []


func setup(inner: Array[RuneData], middle: Array[RuneData], outer: Array[RuneData]) -> bool:
	if not _validate_ring(inner, RuneData.RuneCategory.ELEMENT, "inner"):
		return false
	if not _validate_ring(middle, RuneData.RuneCategory.SHAPE, "middle"):
		return false
	if not _validate_ring(outer, RuneData.RuneCategory.MODIFIER, "outer"):
		return false

	var new_inner := RingModel.new()
	var new_middle := RingModel.new()
	var new_outer := RingModel.new()
	if not new_inner.setup(RING_INNER, inner):
		push_error("RingController.setup: failed to setup inner ring")
		return false
	if not new_middle.setup(RING_MIDDLE, middle):
		push_error("RingController.setup: failed to setup middle ring")
		return false
	if not new_outer.setup(RING_OUTER, outer):
		push_error("RingController.setup: failed to setup outer ring")
		return false

	_inner = new_inner
	_middle = new_middle
	_outer = new_outer
	_undo_stack.clear()
	remaining_rotations = 0
	_configured = true
	return true


func is_configured() -> bool:
	return _configured


func begin_turn() -> bool:
	if not _configured:
		return false
	_undo_stack.clear()
	remaining_rotations = MAX_ROTATIONS
	rotations_changed.emit(remaining_rotations)
	_emit_active_runes_changed()
	return true


func try_rotate(ring_id: StringName, direction: int) -> bool:
	if not _configured:
		return false
	var model := _get_model(ring_id)
	if model == null:
		push_error("RingController: unknown ring_id '%s'" % String(ring_id))
		return false
	if direction != 1 and direction != -1:
		return false
	if not can_rotate():
		return false

	var previous_index := model.get_active_index()
	if not model.rotate(direction):
		return false

	_undo_stack.push_back({&"ring_id": ring_id, &"previous_index": previous_index})
	remaining_rotations -= 1
	ring_rotated.emit(ring_id, direction, model.get_active_index())
	rotations_changed.emit(remaining_rotations)
	_emit_active_runes_changed()
	return true


func undo() -> bool:
	if not _configured:
		return false
	if _undo_stack.is_empty():
		return false

	var record: Dictionary = _undo_stack.pop_back()
	var ring_id: StringName = record[&"ring_id"]
	var previous_index: int = record[&"previous_index"]
	var model := _get_model(ring_id)
	if model == null:
		push_error("RingController.undo: unknown ring_id '%s'" % String(ring_id))
		return false
	model.set_active_index(previous_index)
	remaining_rotations = mini(MAX_ROTATIONS, remaining_rotations + 1)
	ring_rotation_undone.emit(ring_id, model.get_active_index())
	rotations_changed.emit(remaining_rotations)
	_emit_active_runes_changed()
	return true


func can_rotate() -> bool:
	return _configured and remaining_rotations > 0


func can_undo() -> bool:
	return _configured and not _undo_stack.is_empty()


func get_active_runes() -> Dictionary:
	if not _configured:
		return {}
	return {
		&"element": get_active_element(),
		&"shape": get_active_shape(),
		&"modifier": get_active_modifier(),
	}


func get_active_element() -> RuneData:
	if not _configured or _inner == null:
		return null
	return _inner.get_active_rune()


func get_active_shape() -> RuneData:
	if not _configured or _middle == null:
		return null
	return _middle.get_active_rune()


func get_active_modifier() -> RuneData:
	if not _configured or _outer == null:
		return null
	return _outer.get_active_rune()


func get_remaining_rotations() -> int:
	return remaining_rotations


func get_ring_slots(ring_id: StringName) -> Array[RuneData]:
	if not _configured:
		return [] as Array[RuneData]
	var model := _get_model(ring_id)
	if model == null:
		push_error("RingController: unknown ring_id '%s'" % String(ring_id))
		return [] as Array[RuneData]
	return model.slots.duplicate()


func get_active_index(ring_id: StringName) -> int:
	if not _configured:
		return -1
	var model := _get_model(ring_id)
	if model == null:
		push_error("RingController: unknown ring_id '%s'" % String(ring_id))
		return -1
	return model.get_active_index()


func _get_model(ring_id: StringName) -> RingModel:
	match ring_id:
		RING_INNER:
			return _inner
		RING_MIDDLE:
			return _middle
		RING_OUTER:
			return _outer
		_:
			return null


func _validate_ring(slots: Array[RuneData], expected: RuneData.RuneCategory, label: String) -> bool:
	if slots.size() != 4:
		push_error("RingController.setup: %s must have exactly 4 slots" % label)
		return false
	for rune in slots:
		if rune == null:
			push_error("RingController.setup: %s contains null rune" % label)
			return false
		if rune.category != expected:
			push_error("RingController.setup: %s has wrong category" % label)
			return false
	return true


func _emit_active_runes_changed() -> void:
	active_runes_changed.emit(get_active_element(), get_active_shape(), get_active_modifier())
