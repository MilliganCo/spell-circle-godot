class_name EnemyActor
extends Node2D

signal move_completed(enemy: EnemyActor, from_cell: Vector2i, to_cell: Vector2i)

var runtime_id: int = -1
var spawn_order: int = -1
var data: EnemyData
var grid_position: Vector2i = Vector2i.ZERO
var current_health: int = 0
var board: BoardManager
var player: PlayerActor

func setup(
	p_runtime_id: int,
	p_spawn_order: int,
	p_data: EnemyData,
	cell: Vector2i,
	p_board: BoardManager,
	p_player: PlayerActor
) -> void:
	runtime_id = p_runtime_id
	spawn_order = p_spawn_order
	data = p_data
	grid_position = cell
	board = p_board
	player = p_player
	current_health = p_data.max_health


func perform_turn() -> void:
	if board == null or player == null or data == null:
		return
	var steps: int = maxi(0, data.movement_points)
	for _i in steps:
		var dist: int = board.get_manhattan_distance_to_center(grid_position)
		if dist == 1:
			player.take_damage(data.damage)
			return
		if dist <= 0:
			return
		var next_cell := _choose_step_cell()
		if next_cell == grid_position:
			return
		var from_cell := grid_position
		if board.move_occupant(from_cell, next_cell, runtime_id):
			grid_position = next_cell
			sync_visual()
			move_completed.emit(self, from_cell, next_cell)
		else:
			return


func _choose_step_cell() -> Vector2i:
	var current_dist: int = board.get_manhattan_distance_to_center(grid_position)
	var neighbors: Array[Vector2i] = board.get_neighbors4(grid_position)
	for cell in neighbors:
		if board.is_occupied(cell):
			continue
		if board.get_manhattan_distance_to_center(cell) < current_dist:
			return cell
	return grid_position


func sync_visual() -> void:
	if board == null:
		return
	global_position = board.cell_to_world(grid_position)
