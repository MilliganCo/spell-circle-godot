class_name EnemyManager
extends Node2D

signal enemy_spawned(enemy: EnemyActor)
signal enemy_moved(enemy: EnemyActor, from_cell: Vector2i, to_cell: Vector2i)

var board: BoardManager
var player: PlayerActor
var enemy_container: Node

var _registry: Array[EnemyActor] = []
var _next_runtime_id: int = 1
var _next_spawn_order: int = 0


func setup(p_board: BoardManager, p_player: PlayerActor, p_enemy_container: Node) -> void:
	board = p_board
	player = p_player
	enemy_container = p_enemy_container


func spawn_enemy(data: EnemyData, cell: Vector2i) -> EnemyActor:
	if board == null or player == null:
		push_error("spawn_enemy: manager is not configured")
		return null

	if enemy_container == null or not is_instance_valid(enemy_container):
		push_error("spawn_enemy: enemy container is invalid")
		return null

	if data == null or data.scene == null:
		push_error("spawn_enemy: data or scene missing")
		return null

	if not board.is_inside(cell) or board.is_occupied(cell):
		push_error("spawn_enemy: invalid or occupied cell %s" % str(cell))
		return null

	var instance: Node = data.scene.instantiate()
	if instance == null:
		push_error("spawn_enemy: scene instantiation failed")
		return null

	if not (instance is EnemyActor):
		push_error("spawn_enemy: scene root is not EnemyActor")
		instance.free()
		return null

	var enemy := instance as EnemyActor
	var runtime_id := _next_runtime_id
	var spawn_order := _next_spawn_order

	if not board.set_occupant(cell, runtime_id):
		push_error("spawn_enemy: set_occupant failed at %s" % str(cell))
		enemy.free()
		return null

	enemy.setup(
		runtime_id,
		spawn_order,
		data,
		cell,
		board,
		player
	)

	enemy_container.add_child(enemy)
	enemy.move_completed.connect(_on_enemy_move_completed)
	_registry.append(enemy)
	enemy.sync_visual()

	_next_runtime_id += 1
	_next_spawn_order += 1

	enemy_spawned.emit(enemy)
	return enemy


func step_all() -> void:
	var ordered: Array[EnemyActor] = _registry.duplicate()
	ordered.sort_custom(func(a: EnemyActor, b: EnemyActor) -> bool:
		var da: int = board.get_manhattan_distance_to_center(a.grid_position)
		var db: int = board.get_manhattan_distance_to_center(b.grid_position)
		if da != db:
			return da < db
		if a.spawn_order != b.spawn_order:
			return a.spawn_order < b.spawn_order
		return a.runtime_id < b.runtime_id
	)
	for enemy in ordered:
		if is_instance_valid(enemy):
			enemy.perform_turn()


func unregister(enemy: EnemyActor) -> void:
	_registry.erase(enemy)


func _on_enemy_move_completed(enemy: EnemyActor, from_cell: Vector2i, to_cell: Vector2i) -> void:
	enemy_moved.emit(enemy, from_cell, to_cell)
