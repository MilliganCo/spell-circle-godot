class_name PlayerActor
extends Node2D

signal health_changed(current: int, maximum: int)
signal died

const PLAYER_OCCUPANT_ID: int = 0

var board: BoardManager
var max_health: int = 10
var health: int = 10
var shield: int = 0
var grid_position: Vector2i = Vector2i(4, 4)

func setup(p_board: BoardManager) -> void:
	board = p_board


func place_on_board(cell: Vector2i) -> void:
	if board == null:
		push_error("PlayerActor: board is not configured")
		return

	if not board.set_occupant(cell, PLAYER_OCCUPANT_ID):
		push_error("Failed to place player at %s" % str(cell))
		return

	grid_position = cell
	sync_visual()
	health_changed.emit(health, max_health)


func take_damage(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var remaining := amount
	if shield > 0:
		var absorbed: int = mini(shield, remaining)
		shield -= absorbed
		remaining -= absorbed
	if remaining > 0:
		health = maxi(0, health - remaining)
	health_changed.emit(health, max_health)
	if health <= 0:
		died.emit()


func is_dead() -> bool:
	return health <= 0


func sync_visual() -> void:
	if board == null:
		return
	global_position = board.cell_to_world(grid_position)
