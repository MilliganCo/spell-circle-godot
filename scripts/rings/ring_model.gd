class_name RingModel
extends RefCounted

var ring_id: StringName
var slots: Array[RuneData] = []
var active_index: int = 0


func setup(p_ring_id: StringName, p_slots: Array[RuneData]) -> bool:
	if p_slots.size() != 4:
		return false
	for rune in p_slots:
		if rune == null:
			return false
	ring_id = p_ring_id
	slots = p_slots.duplicate()
	active_index = 0
	return true


func rotate(direction: int) -> bool:
	if slots.size() != 4:
		return false
	if direction != 1 and direction != -1:
		return false
	active_index = posmod(active_index + direction, slots.size())
	return true


func get_active_rune() -> RuneData:
	if slots.size() != 4:
		return null
	return slots[active_index]


func get_active_index() -> int:
	return active_index


func set_active_index(index: int) -> bool:
	if slots.size() != 4:
		return false
	active_index = posmod(index, slots.size())
	return true
