extends SceneTree

const PLAYER_OCCUPANT_ID := 0
const CELL_SIZE_PX := 64

var spawn_count := 0
var last_spawned: EnemyActor = null

func _initialize() -> void:
	var failed := 0
	failed += _test_manhattan()
	failed += _test_neighbors_order()
	failed += _test_edge_north_order()
	failed += _test_set_occupant_rejects_other()
	failed += _test_move_occupant_atomic_fail()
	failed += _test_clear_occupant_wrong_id()
	failed += _test_cell_to_world_center()
	failed += _test_player_damage_and_death()
	failed += _test_crawler_step_south()
	failed += _test_crawler_attack_adjacent()
	failed += _test_crawler_priority_east()
	failed += _test_spawn_occupied_does_not_consume_id()
	failed += _test_step_all_adjacent_attacks()
	failed += _test_signals_spawn_and_move()
	failed += _test_step_all_order_closer_first()
	_finish(failed)


func _make_board() -> BoardManager:
	var board := BoardManager.new()
	board.name = "Board"
	root.add_child(board)
	board.initialize(9, Vector2i(4, 4))
	return board


func _test_manhattan() -> int:
	var board := _make_board()
	var ok := board.get_manhattan_distance_to_center(Vector2i(0, 0)) == 8
	board.queue_free()
	return _expect(ok, "manhattan (0,0) from center == 8")


func _test_neighbors_order() -> int:
	var board := _make_board()
	var n: Array[Vector2i] = board.get_neighbors4(Vector2i(4, 4))
	var ok := n.size() == 4 \
		and n[0] == Vector2i(4, 3) \
		and n[1] == Vector2i(5, 4) \
		and n[2] == Vector2i(4, 5) \
		and n[3] == Vector2i(3, 4)
	board.queue_free()
	return _expect(ok, "neighbors4(center) == N,E,S,W")


func _test_edge_north_order() -> int:
	var board := _make_board()
	var cells: Array[Vector2i] = board.get_edge_spawn_cells(&"north")
	var ok := cells.size() == 9 and cells[0] == Vector2i(0, 0) and cells[8] == Vector2i(8, 0)
	board.queue_free()
	return _expect(ok, "north edge (0,0)->(8,0)")


func _test_set_occupant_rejects_other() -> int:
	var board := _make_board()
	var a := board.set_occupant(Vector2i(1, 1), 1)
	var b := board.set_occupant(Vector2i(1, 1), 2)
	var ok := a and (not b) and board.get_occupant(Vector2i(1, 1)) == 1
	board.queue_free()
	return _expect(ok, "set_occupant rejects other id")


func _test_move_occupant_atomic_fail() -> int:
	var board := _make_board()
	board.set_occupant(Vector2i(2, 2), 1)
	board.set_occupant(Vector2i(2, 3), 2)
	var moved := board.move_occupant(Vector2i(2, 2), Vector2i(2, 3), 1)
	var ok := (not moved) \
		and board.get_occupant(Vector2i(2, 2)) == 1 \
		and board.get_occupant(Vector2i(2, 3)) == 2
	board.queue_free()
	return _expect(ok, "move_occupant failure leaves both cells")


func _test_clear_occupant_wrong_id() -> int:
	var board := _make_board()
	board.set_occupant(Vector2i(3, 3), 5)
	var cleared := board.clear_occupant(Vector2i(3, 3), 9)
	var ok := (not cleared) and board.get_occupant(Vector2i(3, 3)) == 5
	board.queue_free()
	return _expect(ok, "clear_occupant wrong id fails")


func _test_player_damage_and_death() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var ok := board.get_occupant(Vector2i(4, 4)) == PLAYER_OCCUPANT_ID
	player.take_damage(1)
	ok = ok and player.health == 9
	for i in 9:
		player.take_damage(1)
	ok = ok and player.health == 0 and player.is_dead()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "player place + damage to death")


func _test_crawler_step_south() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var enemy := EnemyActor.new()
	root.add_child(enemy)
	var data := EnemyData.new()
	data.damage = 1
	data.movement_points = 1
	data.max_health = 3
	data.behavior_id = &"greedy_center"
	board.set_occupant(Vector2i(4, 0), 1)
	enemy.setup(1, 0, data, Vector2i(4, 0), board, player)
	enemy.perform_turn()
	var ok := enemy.grid_position == Vector2i(4, 1) and board.get_occupant(Vector2i(4, 1)) == 1
	enemy.queue_free()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "crawler (4,0) -> (4,1)")


func _test_crawler_attack_adjacent() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var enemy := EnemyActor.new()
	root.add_child(enemy)
	var data := EnemyData.new()
	data.damage = 1
	data.movement_points = 1
	board.set_occupant(Vector2i(4, 3), 1)
	enemy.setup(1, 0, data, Vector2i(4, 3), board, player)
	enemy.perform_turn()
	var ok := enemy.grid_position == Vector2i(4, 3) \
		and player.health == 9 \
		and board.get_occupant(Vector2i(4, 4)) == PLAYER_OCCUPANT_ID
	enemy.queue_free()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "adjacent attack HP 10->9, stay put")


func _test_crawler_priority_east() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var enemy := EnemyActor.new()
	root.add_child(enemy)
	var data := EnemyData.new()
	data.movement_points = 1
	board.set_occupant(Vector2i(0, 0), 1)
	enemy.setup(1, 0, data, Vector2i(0, 0), board, player)
	enemy.perform_turn()
	var ok := enemy.grid_position == Vector2i(1, 0)
	enemy.queue_free()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "from (0,0) chooses (1,0)")


func _make_crawler_data() -> EnemyData:
	var data := EnemyData.new()
	data.scene = load("res://scenes/entities/enemies/crawler.tscn")
	data.max_health = 3
	data.damage = 1
	data.movement_points = 1
	data.behavior_id = &"greedy_center"
	return data


func _test_spawn_occupied_does_not_consume_id() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var manager := EnemyManager.new()
	root.add_child(manager)
	manager.setup(board, player, manager)
	var data := _make_crawler_data()
	var first: EnemyActor = manager.spawn_enemy(data, Vector2i(4, 0))
	var failed: EnemyActor = manager.spawn_enemy(data, Vector2i(4, 0))
	var next: EnemyActor = manager.spawn_enemy(data, Vector2i(5, 0))
	var ok := first != null \
		and first.runtime_id == 1 \
		and failed == null \
		and next != null \
		and next.runtime_id == 2 \
		and manager.get_child_count() == 2
	manager.queue_free()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "failed spawn does not consume runtime id")


func _test_step_all_adjacent_attacks() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var manager := EnemyManager.new()
	root.add_child(manager)
	manager.setup(board, player, manager)
	var data := _make_crawler_data()
	var enemy: EnemyActor = manager.spawn_enemy(data, Vector2i(4, 3))
	manager.step_all()
	var ok := enemy.grid_position == Vector2i(4, 3) and player.health == 9
	manager.queue_free()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "step_all adjacent attacks")


func _test_signals_spawn_and_move() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var manager := EnemyManager.new()
	root.add_child(manager)
	manager.setup(board, player, manager)
	var data := _make_crawler_data()

	spawn_count = 0
	last_spawned = null
	manager.enemy_spawned.connect(func(e: EnemyActor) -> void:
		spawn_count += 1
		last_spawned = e
	)

	var moved: Array = []
	manager.enemy_moved.connect(func(e: EnemyActor, from_cell: Vector2i, to_cell: Vector2i) -> void:
		moved.append({"enemy": e, "from": from_cell, "to": to_cell})
	)

	var enemy: EnemyActor = manager.spawn_enemy(data, Vector2i(4, 0))
	var failed: EnemyActor = manager.spawn_enemy(data, Vector2i(4, 0))
	var ok := enemy != null and failed == null and spawn_count == 1 and last_spawned == enemy

	manager.step_all()
	ok = ok and moved.size() == 1 \
		and moved[0]["enemy"] == enemy \
		and moved[0]["from"] == Vector2i(4, 0) \
		and moved[0]["to"] == Vector2i(4, 1)

	board.clear_occupant(Vector2i(4, 1), enemy.runtime_id)
	board.set_occupant(Vector2i(4, 3), enemy.runtime_id)
	enemy.grid_position = Vector2i(4, 3)
	moved.clear()
	manager.step_all()
	ok = ok and moved.is_empty() and player.health == 9

	manager.queue_free()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "enemy_spawned / enemy_moved signal contracts")


func _test_step_all_order_closer_first() -> int:
	var board := _make_board()
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var manager := EnemyManager.new()
	root.add_child(manager)
	manager.setup(board, player, manager)
	var data := _make_crawler_data()
	var enemy_a: EnemyActor = manager.spawn_enemy(data, Vector2i(4, 0))
	var enemy_b: EnemyActor = manager.spawn_enemy(data, Vector2i(4, 2))
	var moved_ids: Array[int] = []
	manager.enemy_moved.connect(func(e: EnemyActor, _from: Vector2i, _to: Vector2i) -> void:
		moved_ids.append(e.runtime_id)
	)
	manager.step_all()
	var ok := moved_ids.size() == 2 \
		and moved_ids[0] == enemy_b.runtime_id \
		and moved_ids[1] == enemy_a.runtime_id \
		and enemy_b.grid_position == Vector2i(4, 3) \
		and enemy_a.grid_position == Vector2i(4, 1)
	manager.queue_free()
	player.queue_free()
	board.queue_free()
	return _expect(ok, "step_all closer enemy acts first")


func _test_cell_to_world_center() -> int:
	var board := _make_board()
	# Board at identity transform: local center (0,0) == (32,32) == global
	var world: Vector2 = board.cell_to_world(Vector2i(0, 0))
	var ok := is_equal_approx(world.x, 32.0) and is_equal_approx(world.y, 32.0)
	board.queue_free()
	return _expect(ok, "cell_to_world(0,0) center == (32,32)")


func _expect(condition: bool, message: String) -> int:
	if condition:
		print("PASS: ", message)
		return 0
	push_error("FAIL: " + message)
	print("FAIL: ", message)
	return 1


func _finish(failed: int) -> void:
	if failed == 0:
		print("All tests passed.")
		quit(0)
	else:
		print("Tests failed: ", failed)
		quit(1)
