class_name BoardManager
extends Node2D

const CELL_SIZE_PX: int = 64
const PLAYER_OCCUPANT_ID: int = 0

var board_size: int = 9
var center: Vector2i = Vector2i(4, 4)
var _cells: Dictionary = {} # Vector2i -> BoardCellState

func initialize(size: int, p_center: Vector2i) -> void:
	board_size = size
	center = p_center
	_cells.clear()
	for y in range(size):
		for x in range(size):
			var cell := Vector2i(x, y)
			var state := BoardCellState.new()
			state.coordinates = cell
			state.occupant_id = -1
			state.terrain_type = &"normal"
			if cell == center:
				state.terrain_type = &"player_center"
			elif _is_edge(cell, size):
				state.terrain_type = &"spawn_edge"
			_cells[cell] = state


func _is_edge(cell: Vector2i, size: int) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == size - 1 or cell.y == size - 1


func cell_to_world(cell: Vector2i) -> Vector2:
	var local := Vector2((cell.x + 0.5) * CELL_SIZE_PX, (cell.y + 0.5) * CELL_SIZE_PX)
	return to_global(local)


func world_to_cell(world: Vector2) -> Vector2i:
	var local := to_local(world)
	return Vector2i(floori(local.x / CELL_SIZE_PX), floori(local.y / CELL_SIZE_PX))


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < board_size and cell.y < board_size


func is_occupied(cell: Vector2i) -> bool:
	if not is_inside(cell):
		return false
	return (_cells[cell] as BoardCellState).occupant_id != -1


func get_occupant(cell: Vector2i) -> int:
	if not is_inside(cell):
		return -1
	return (_cells[cell] as BoardCellState).occupant_id


func set_occupant(cell: Vector2i, occupant_id: int) -> bool:
	if not is_inside(cell):
		return false
	var state := _cells[cell] as BoardCellState
	if state.occupant_id != -1 and state.occupant_id != occupant_id:
		return false
	state.occupant_id = occupant_id
	return true


func clear_occupant(cell: Vector2i, expected_id: int) -> bool:
	if not is_inside(cell):
		return false
	var state := _cells[cell] as BoardCellState
	if state.occupant_id != expected_id:
		return false
	state.occupant_id = -1
	return true


func move_occupant(from_cell: Vector2i, to_cell: Vector2i, occupant_id: int) -> bool:
	if not is_inside(from_cell) or not is_inside(to_cell):
		return false
	var from_state := _cells[from_cell] as BoardCellState
	var to_state := _cells[to_cell] as BoardCellState
	if from_state.occupant_id != occupant_id:
		return false
	if to_state.occupant_id != -1:
		return false
	from_state.occupant_id = -1
	to_state.occupant_id = occupant_id
	return true


func get_manhattan_distance_to_center(cell: Vector2i) -> int:
	return absi(cell.x - center.x) + absi(cell.y - center.y)


func get_neighbors4(cell: Vector2i) -> Array[Vector2i]:
	var deltas: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1, 0),
		Vector2i(0, 1),
		Vector2i(-1, 0),
	]
	var result: Array[Vector2i] = []
	for d in deltas:
		var n: Vector2i = cell + d
		if is_inside(n):
			result.append(n)
	return result


func get_edge_spawn_cells(side: StringName) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	match side:
		&"north":
			for x in range(board_size):
				result.append(Vector2i(x, 0))
		&"east":
			for y in range(board_size):
				result.append(Vector2i(board_size - 1, y))
		&"south":
			for x in range(board_size):
				result.append(Vector2i(x, board_size - 1))
		&"west":
			for y in range(board_size):
				result.append(Vector2i(0, y))
		_:
			push_error("Unknown edge side: %s" % String(side))
	return result


func get_cell_state(cell: Vector2i) -> BoardCellState:
	if not is_inside(cell):
		return null
	return _cells[cell] as BoardCellState
