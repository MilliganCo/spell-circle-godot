extends SceneTree

var _journal: PackedStringArray = PackedStringArray()
var _phase_enemy_action_count: int = 0


func _initialize() -> void:
	var failed := 0
	failed += _test_start_run_without_setup()
	failed += _test_start_run_once()
	failed += _test_end_turn_event_journal()
	failed += _test_one_step_all_per_end_turn()
	failed += _test_nested_end_turn_ignored()
	failed += _test_two_cycles_turn_number_3()
	failed += _test_defeat_halt()
	_finish(failed)


func _expect(condition: bool, message: String) -> int:
	if condition:
		print("PASS: ", message)
		return 0
	push_error("FAIL: " + message)
	print("FAIL: ", message)
	return 1


func _finish(failed: int) -> void:
	if failed == 0:
		print("All Stage 2 TurnManager tests passed.")
		quit(0)
	else:
		print("Stage 2 tests failed: ", failed)
		quit(1)


func _phase_name(phase: TurnManager.Phase) -> String:
	return TurnManager.Phase.keys()[phase]


func _make_harness() -> Dictionary:
	var board := BoardManager.new()
	root.add_child(board)
	board.initialize(9, Vector2i(4, 4))
	var player := PlayerActor.new()
	root.add_child(player)
	player.setup(board)
	player.place_on_board(Vector2i(4, 4))
	var enemies := CountingEnemyManager.new()
	root.add_child(enemies)
	enemies.setup(board, player, enemies)
	var tm := TurnManager.new()
	root.add_child(tm)
	return {"board": board, "player": player, "enemies": enemies, "tm": tm}


func _wire_journal(tm: TurnManager) -> void:
	_journal.clear()
	_phase_enemy_action_count = 0
	tm.phase_changed.connect(func(phase: TurnManager.Phase) -> void:
		_journal.append("phase:%s" % _phase_name(phase))
		if phase == TurnManager.Phase.ENEMY_ACTION:
			_phase_enemy_action_count += 1
	)
	tm.turn_started.connect(func(n: int) -> void:
		_journal.append("turn_started:%d" % n)
	)
	tm.turn_ended.connect(func(n: int) -> void:
		_journal.append("turn_ended:%d" % n)
	)
	tm.input_lock_changed.connect(func(locked: bool) -> void:
		_journal.append("lock:%s" % ("true" if locked else "false"))
	)


func _cleanup(h: Dictionary) -> void:
	h["tm"].queue_free()
	h["enemies"].queue_free()
	h["player"].queue_free()
	h["board"].queue_free()


func _test_start_run_without_setup() -> int:
	var tm := TurnManager.new()
	root.add_child(tm)
	tm.start_run()
	var ok := tm.get_turn_number() == 0 \
		and tm.is_input_locked() \
		and not tm.can_accept_player_input() \
		and not tm.is_halted()
	tm.queue_free()
	return _expect(ok, "start_run without setup leaves idle locked state")


func _test_start_run_once() -> int:
	var h := _make_harness()
	var tm: TurnManager = h["tm"]
	tm.setup(h["enemies"], h["player"])
	tm.start_run()
	var ok := tm.get_turn_number() == 1 \
		and tm.get_current_phase() == TurnManager.Phase.PLAYER_ROTATE \
		and tm.can_accept_player_input() \
		and not tm.is_input_locked()
	tm.start_run()
	ok = ok and tm.get_turn_number() == 1
	_cleanup(h)
	return _expect(ok, "start_run once → turn 1 PLAYER_ROTATE; repeat noop")


func _test_end_turn_event_journal() -> int:
	var h := _make_harness()
	var tm: TurnManager = h["tm"]
	tm.setup(h["enemies"], h["player"])
	_wire_journal(tm)
	tm.start_run()
	# Drop startup events; keep only End Turn pipeline from lock:true
	var start_len := _journal.size()
	tm.request_end_turn()
	var events: PackedStringArray = PackedStringArray()
	for i in range(start_len, _journal.size()):
		events.append(_journal[i])
	var expected := PackedStringArray([
		"lock:true",
		"phase:PLAYER_TARGET",
		"phase:PLAYER_CAST",
		"phase:SPELL_RESOLUTION",
		"phase:ENEMY_PREPARE",
		"phase:ENEMY_ACTION",
		"phase:ENVIRONMENT_RESOLUTION",
		"phase:TURN_END",
		"turn_ended:1",
		"phase:PLAYER_PREPARE",
		"turn_started:2",
		"phase:PLAYER_ROTATE",
		"lock:false",
	])
	var ok := events == expected
	if not ok:
		print("GOT: ", " | ".join(events))
		print("EXP: ", " | ".join(expected))
	_cleanup(h)
	return _expect(ok, "End Turn event journal order")


func _test_one_step_all_per_end_turn() -> int:
	var h := _make_harness()
	var tm: TurnManager = h["tm"]
	var enemies: CountingEnemyManager = h["enemies"]
	var data := EnemyData.new()
	data.scene = load("res://scenes/entities/enemies/crawler.tscn")
	data.max_health = 3
	data.damage = 1
	data.movement_points = 1
	enemies.spawn_enemy(data, Vector2i(4, 0))
	tm.setup(enemies, h["player"])
	tm.start_run()
	enemies.step_all_count = 0
	tm.request_end_turn()
	var ok := enemies.step_all_count == 1
	_cleanup(h)
	return _expect(ok, "exactly one step_all per End Turn")


func _test_nested_end_turn_ignored() -> int:
	var h := _make_harness()
	var tm: TurnManager = h["tm"]
	var enemies: CountingEnemyManager = h["enemies"]
	var data := EnemyData.new()
	data.scene = load("res://scenes/entities/enemies/crawler.tscn")
	data.max_health = 3
	data.damage = 1
	data.movement_points = 1
	enemies.spawn_enemy(data, Vector2i(4, 0))
	tm.setup(enemies, h["player"])
	_wire_journal(tm)
	tm.start_run()
	enemies.step_all_count = 0
	_phase_enemy_action_count = 0
	tm.phase_changed.connect(func(phase: TurnManager.Phase) -> void:
		if phase == TurnManager.Phase.PLAYER_TARGET:
			tm.request_end_turn()
	)
	tm.request_end_turn()
	var ok := enemies.step_all_count == 1 \
		and _phase_enemy_action_count == 1 \
		and tm.get_turn_number() == 2 \
		and tm.get_current_phase() == TurnManager.Phase.PLAYER_ROTATE
	_cleanup(h)
	return _expect(ok, "nested End Turn on PLAYER_TARGET ignored")


func _test_two_cycles_turn_number_3() -> int:
	var h := _make_harness()
	var tm: TurnManager = h["tm"]
	tm.setup(h["enemies"], h["player"])
	tm.start_run()
	tm.request_end_turn()
	tm.request_end_turn()
	var ok := tm.get_turn_number() == 3 \
		and tm.get_current_phase() == TurnManager.Phase.PLAYER_ROTATE
	_cleanup(h)
	return _expect(ok, "two End Turns → turn_number 3 at PLAYER_ROTATE")


func _test_defeat_halt() -> int:
	var h := _make_harness()
	var tm: TurnManager = h["tm"]
	var player: PlayerActor = h["player"]
	var enemies: CountingEnemyManager = h["enemies"]
	var data := EnemyData.new()
	data.scene = load("res://scenes/entities/enemies/crawler.tscn")
	data.max_health = 3
	data.damage = 1
	data.movement_points = 1
	enemies.spawn_enemy(data, Vector2i(4, 3))
	tm.setup(enemies, player)
	_wire_journal(tm)
	tm.start_run()
	var guard := 0
	while not tm.is_halted() and guard < 20:
		tm.request_end_turn()
		guard += 1
	var last := _journal[_journal.size() - 1]
	var second_last := _journal[_journal.size() - 2]
	var has_prepare_after_last_end := false
	# Find last turn_ended and ensure no PLAYER_PREPARE / lock:false after it
	var last_ended_idx := -1
	for i in range(_journal.size()):
		if _journal[i].begins_with("turn_ended:"):
			last_ended_idx = i
	if last_ended_idx >= 0:
		for j in range(last_ended_idx + 1, _journal.size()):
			if _journal[j] == "phase:PLAYER_PREPARE" or _journal[j] == "lock:false":
				has_prepare_after_last_end = true
	var ok := tm.is_halted() \
		and player.is_dead() \
		and not tm.can_accept_player_input() \
		and tm.is_input_locked() \
		and second_last == "phase:TURN_END" \
		and last.begins_with("turn_ended:") \
		and not has_prepare_after_last_end
	_cleanup(h)
	return _expect(ok, "defeat halt: TURN_END + turn_ended, no unlock/prepare")
