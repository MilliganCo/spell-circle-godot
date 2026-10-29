extends SceneTree

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failed := 0
	failed += _test_ring_model_valid_setup()
	failed += _test_ring_model_rotate()
	failed += _test_ring_model_invalid_direction()
	failed += _test_ring_model_set_active_index()
	failed += _test_ring_model_slot_array_isolation()
	failed += _test_controller_starter_identity()
	failed += _test_controller_setup_atomicity()
	failed += _test_controller_unconfigured_ops()
	failed += _test_controller_budget_undo_signals()
	failed += _test_controller_can_rotate_timeline()
	failed += _test_controller_orientation_persists()
	failed += _test_visual_position_math()
	failed += await _test_ring_visuals_setup_and_refresh()
	failed += await _test_ring_visuals_setup_atomic()
	failed += await _test_game_controller_begin_turn_journal()
	failed += await _test_game_controller_reentrant_end_turn()
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
		print("All Stage 3 rings tests passed.")
		quit(0)
	else:
		print("Stage 3 tests failed: ", failed)
		quit(1)


func _make_rune(id: StringName, category: RuneData.RuneCategory) -> RuneData:
	var r := RuneData.new()
	r.id = id
	r.display_name = String(id)
	r.category = category
	return r


func _test_ring_model_valid_setup() -> int:
	var fire := _make_rune(&"fire", RuneData.RuneCategory.ELEMENT)
	var ice := _make_rune(&"ice", RuneData.RuneCategory.ELEMENT)
	var lightning := _make_rune(&"lightning", RuneData.RuneCategory.ELEMENT)
	var model := RingModel.new()
	var ok := model.setup(&"inner", [fire, ice, lightning, fire] as Array[RuneData])
	return _expect(ok and model.get_active_index() == 0 and model.get_active_rune() == fire, "RingModel valid setup")


func _test_ring_model_rotate() -> int:
	var a := _make_rune(&"a", RuneData.RuneCategory.ELEMENT)
	var b := _make_rune(&"b", RuneData.RuneCategory.ELEMENT)
	var c := _make_rune(&"c", RuneData.RuneCategory.ELEMENT)
	var d := _make_rune(&"d", RuneData.RuneCategory.ELEMENT)
	var model := RingModel.new()
	model.setup(&"inner", [a, b, c, d] as Array[RuneData])
	var f := 0
	f += _expect(model.rotate(1) and model.get_active_index() == 1 and model.get_active_rune() == b, "rotate +1")
	f += _expect(model.rotate(1) and model.get_active_index() == 2, "rotate +1 again")
	f += _expect(model.rotate(1) and model.get_active_index() == 3, "rotate +1 to 3")
	f += _expect(model.rotate(1) and model.get_active_index() == 0, "rotate +1 wrap")
	f += _expect(model.rotate(-1) and model.get_active_index() == 3, "rotate -1 wrap")
	return f


func _test_ring_model_invalid_direction() -> int:
	var a := _make_rune(&"a", RuneData.RuneCategory.ELEMENT)
	var model := RingModel.new()
	model.setup(&"inner", [a, a, a, a] as Array[RuneData])
	var before := model.get_active_index()
	return _expect(not model.rotate(0) and not model.rotate(2) and model.get_active_index() == before, "invalid direction")


func _test_ring_model_set_active_index() -> int:
	var a := _make_rune(&"a", RuneData.RuneCategory.ELEMENT)
	var fresh := RingModel.new()
	var f := 0
	f += _expect(not fresh.set_active_index(1) and fresh.get_active_index() == 0, "set_active before setup")
	fresh.setup(&"inner", [a, a, a, a] as Array[RuneData])
	f += _expect(fresh.set_active_index(4) and fresh.get_active_index() == 0, "set_active 4->0")
	f += _expect(fresh.set_active_index(-1) and fresh.get_active_index() == 3, "set_active -1->3")
	return f


func _test_ring_model_slot_array_isolation() -> int:
	var fire := _make_rune(&"fire", RuneData.RuneCategory.ELEMENT)
	var ice := _make_rune(&"ice", RuneData.RuneCategory.ELEMENT)
	var lightning := _make_rune(&"lightning", RuneData.RuneCategory.ELEMENT)
	var source: Array[RuneData] = [fire, ice, lightning, fire]
	var model := RingModel.new()
	model.setup(&"inner", source)
	source[0] = ice
	var f := 0
	f += _expect(model.get_active_rune() == fire, "duplicate isolates slots")
	var bad: Array[RuneData] = [fire, ice, lightning]
	f += _expect(not model.setup(&"other", bad) and model.ring_id == &"inner" and model.get_active_rune() == fire, "invalid re-setup keeps prior")
	return f


func _make_controller_configured() -> RingController:
	var c := RingController.new()
	root.add_child(c)
	var layout := StarterRingLayout.build()
	assert(c.setup(layout[&"inner"], layout[&"middle"], layout[&"outer"]))
	return c


func _wire_controller_journal(c: RingController, journal: PackedStringArray) -> void:
	c.ring_rotated.connect(func(ring_id: StringName, direction: int, active_index: int) -> void:
		journal.append("ring_rotated:%s:%d:%d" % [String(ring_id), direction, active_index])
	)
	c.ring_rotation_undone.connect(func(ring_id: StringName, active_index: int) -> void:
		journal.append("ring_rotation_undone:%s:%d" % [String(ring_id), active_index])
	)
	c.active_runes_changed.connect(func(_e: RuneData, _s: RuneData, _m: RuneData) -> void:
		journal.append("active_runes_changed")
	)
	c.rotations_changed.connect(func(remaining: int) -> void:
		journal.append("rotations_changed:%d" % remaining)
	)


func _make_valid_arrays() -> Dictionary:
	var e0 := _make_rune(&"e0", RuneData.RuneCategory.ELEMENT)
	var e1 := _make_rune(&"e1", RuneData.RuneCategory.ELEMENT)
	var e2 := _make_rune(&"e2", RuneData.RuneCategory.ELEMENT)
	var s0 := _make_rune(&"s0", RuneData.RuneCategory.SHAPE)
	var s1 := _make_rune(&"s1", RuneData.RuneCategory.SHAPE)
	var s2 := _make_rune(&"s2", RuneData.RuneCategory.SHAPE)
	var m0 := _make_rune(&"m0", RuneData.RuneCategory.MODIFIER)
	var m1 := _make_rune(&"m1", RuneData.RuneCategory.MODIFIER)
	var m2 := _make_rune(&"m2", RuneData.RuneCategory.MODIFIER)
	var inner: Array[RuneData] = [e0, e1, e2, e0]
	var middle: Array[RuneData] = [s0, s1, s2, s0]
	var outer: Array[RuneData] = [m0, m1, m2, m0]
	return {&"inner": inner, &"middle": middle, &"outer": outer}


func _test_controller_starter_identity() -> int:
	var layout := StarterRingLayout.build()
	var inner: Array[RuneData] = layout[&"inner"]
	var middle: Array[RuneData] = layout[&"middle"]
	var outer: Array[RuneData] = layout[&"outer"]
	var f := 0
	f += _expect(inner[0] == inner[3], "starter inner[0]==inner[3]")
	f += _expect(middle[0] == middle[3], "starter middle[0]==middle[3]")
	f += _expect(outer[0] == outer[3], "starter outer[0]==outer[3]")
	var unique: Array = []
	for slot in inner + middle + outer:
		if not unique.has(slot):
			unique.append(slot)
	f += _expect(unique.size() == 9, "starter 9 unique refs among 12 slots")
	var c := _make_controller_configured()
	f += _expect(c.is_configured(), "starter setup configures controller")
	f += _expect(c.get_active_index(RingController.RING_INNER) == 0, "starter active index 0")
	f += _expect(c.get_remaining_rotations() == 0, "setup leaves remaining at 0")
	c.queue_free()
	return f


func _test_controller_setup_atomicity() -> int:
	var f := 0
	var fresh := RingController.new()
	root.add_child(fresh)
	var journal := PackedStringArray()
	_wire_controller_journal(fresh, journal)
	var short_inner: Array[RuneData] = [
		_make_rune(&"e0", RuneData.RuneCategory.ELEMENT),
		_make_rune(&"e1", RuneData.RuneCategory.ELEMENT),
		_make_rune(&"e2", RuneData.RuneCategory.ELEMENT),
	]
	var valid := _make_valid_arrays()
	f += _expect(
		not fresh.setup(short_inner, valid[&"middle"], valid[&"outer"]) and not fresh.is_configured(),
		"fresh invalid setup stays unconfigured"
	)
	f += _expect(journal.is_empty(), "fresh invalid setup emits no signals")
	fresh.queue_free()

	var c := RingController.new()
	root.add_child(c)
	journal = PackedStringArray()
	_wire_controller_journal(c, journal)
	assert(c.setup(valid[&"inner"], valid[&"middle"], valid[&"outer"]))
	f += _expect(journal.is_empty(), "valid setup emits no HUD signals")
	assert(c.begin_turn())
	assert(c.try_rotate(RingController.RING_INNER, 1))
	var idx_before := c.get_active_index(RingController.RING_INNER)
	var slots_before: Array[RuneData] = c.get_ring_slots(RingController.RING_INNER)
	var rem_before := c.get_remaining_rotations()
	var can_undo_before := c.can_undo()
	journal.clear()
	var bad_null: Array[RuneData] = [
		_make_rune(&"e0", RuneData.RuneCategory.ELEMENT),
		null,
		_make_rune(&"e2", RuneData.RuneCategory.ELEMENT),
		_make_rune(&"e3", RuneData.RuneCategory.ELEMENT),
	]
	f += _expect(
		not c.setup(bad_null, valid[&"middle"], valid[&"outer"]),
		"invalid setup after configured returns false"
	)
	f += _expect(c.is_configured(), "invalid re-setup keeps configured")
	f += _expect(c.get_active_index(RingController.RING_INNER) == idx_before, "invalid re-setup keeps indices")
	f += _expect(c.get_ring_slots(RingController.RING_INNER) == slots_before, "invalid re-setup keeps slots")
	f += _expect(c.get_remaining_rotations() == rem_before, "invalid re-setup keeps remaining")
	f += _expect(c.can_undo() == can_undo_before, "invalid re-setup keeps undo")
	f += _expect(journal.is_empty(), "invalid re-setup emits no signals")
	c.queue_free()
	return f


func _test_controller_unconfigured_ops() -> int:
	var f := 0
	var c := RingController.new()
	root.add_child(c)
	var journal := PackedStringArray()
	_wire_controller_journal(c, journal)
	f += _expect(not c.begin_turn(), "unconfigured begin_turn false")
	f += _expect(not c.try_rotate(RingController.RING_INNER, 1), "unconfigured try_rotate false")
	f += _expect(not c.undo(), "unconfigured undo false")
	f += _expect(not c.can_rotate() and not c.can_undo(), "unconfigured can_rotate/can_undo false")
	f += _expect(c.get_active_runes().is_empty(), "unconfigured get_active_runes empty")
	f += _expect(c.get_active_element() == null, "unconfigured get_active_element null")
	f += _expect(c.get_active_shape() == null, "unconfigured get_active_shape null")
	f += _expect(c.get_active_modifier() == null, "unconfigured get_active_modifier null")
	f += _expect(c.get_remaining_rotations() == 0, "unconfigured remaining 0")
	f += _expect(c.get_active_index(RingController.RING_INNER) == -1, "unconfigured get_active_index -1")
	f += _expect(c.get_ring_slots(RingController.RING_INNER).is_empty(), "unconfigured get_ring_slots empty")
	f += _expect(journal.is_empty(), "unconfigured ops emit no signals")
	c.queue_free()

	var configured := _make_controller_configured()
	journal = PackedStringArray()
	_wire_controller_journal(configured, journal)
	assert(configured.begin_turn())
	journal.clear()
	var rem := configured.get_remaining_rotations()
	f += _expect(configured.get_active_index(&"unknown") == -1, "unknown ring get_active_index -1")
	f += _expect(configured.get_ring_slots(&"unknown").is_empty(), "unknown ring get_ring_slots empty")
	f += _expect(not configured.try_rotate(&"unknown", 1), "unknown ring try_rotate false")
	f += _expect(configured.get_remaining_rotations() == rem, "unknown try_rotate no state change")
	f += _expect(journal.is_empty(), "unknown ring ops emit no signals")
	configured.queue_free()
	return f


func _test_controller_budget_undo_signals() -> int:
	var f := 0
	var c := _make_controller_configured()
	var journal := PackedStringArray()
	_wire_controller_journal(c, journal)
	f += _expect(c.begin_turn(), "begin_turn succeeds")
	f += _expect(c.get_remaining_rotations() == 2, "begin_turn remaining 2")
	f += _expect(
		journal == PackedStringArray(["rotations_changed:2", "active_runes_changed"]),
		"begin_turn signal order"
	)
	journal.clear()
	f += _expect(c.try_rotate(RingController.RING_INNER, 1), "first rotate")
	f += _expect(c.get_remaining_rotations() == 1, "remaining 1 after first rotate")
	f += _expect(
		journal == PackedStringArray([
			"ring_rotated:inner:1:1",
			"rotations_changed:1",
			"active_runes_changed",
		]),
		"rotate signal order"
	)
	journal.clear()
	f += _expect(c.try_rotate(RingController.RING_MIDDLE, -1), "second rotate")
	f += _expect(c.get_remaining_rotations() == 0, "remaining 0 after two rotates")
	journal.clear()
	var idx_inner := c.get_active_index(RingController.RING_INNER)
	f += _expect(not c.try_rotate(RingController.RING_OUTER, 1), "third rotate silent fail")
	f += _expect(c.get_active_index(RingController.RING_INNER) == idx_inner, "failed rotate no index change")
	f += _expect(journal.is_empty(), "failed rotate no signals")
	journal.clear()
	f += _expect(c.undo(), "undo succeeds")
	f += _expect(c.get_remaining_rotations() == 1, "undo restores remaining")
	f += _expect(c.get_active_index(RingController.RING_MIDDLE) == 0, "undo restores middle index")
	f += _expect(
		journal == PackedStringArray([
			"ring_rotation_undone:middle:0",
			"rotations_changed:1",
			"active_runes_changed",
		]),
		"undo signal order"
	)
	journal.clear()
	f += _expect(c.undo(), "second undo")
	f += _expect(c.get_active_index(RingController.RING_INNER) == 0, "second undo restores inner")
	journal.clear()
	f += _expect(not c.undo(), "empty undo false")
	f += _expect(journal.is_empty(), "empty undo no signals")
	c.queue_free()
	return f


func _test_controller_can_rotate_timeline() -> int:
	var f := 0
	var c := _make_controller_configured()
	f += _expect(not c.can_rotate() and not c.can_undo(), "before begin_turn cannot rotate/undo")
	assert(c.begin_turn())
	f += _expect(c.can_rotate() and not c.can_undo(), "after begin_turn can_rotate, no undo")
	assert(c.try_rotate(RingController.RING_INNER, 1))
	f += _expect(c.can_rotate() and c.can_undo(), "after one rotate both true")
	assert(c.try_rotate(RingController.RING_OUTER, 1))
	f += _expect(not c.can_rotate() and c.can_undo(), "after two rotates cannot rotate")
	assert(c.undo())
	assert(c.undo())
	f += _expect(c.get_remaining_rotations() == 2, "two undos restore remaining 2")
	f += _expect(not c.can_undo(), "two undos empty stack")
	f += _expect(c.can_rotate(), "after two undos can_rotate")
	f += _expect(c.get_remaining_rotations() <= RingController.MAX_ROTATIONS, "remaining never > MAX")
	c.queue_free()
	return f


func _test_controller_orientation_persists() -> int:
	var f := 0
	var c := _make_controller_configured()
	assert(c.begin_turn())
	assert(c.try_rotate(RingController.RING_INNER, 1))
	assert(c.try_rotate(RingController.RING_MIDDLE, 1))
	var inner_idx := c.get_active_index(RingController.RING_INNER)
	var middle_idx := c.get_active_index(RingController.RING_MIDDLE)
	f += _expect(c.can_undo(), "undo available before next turn")
	var journal := PackedStringArray()
	_wire_controller_journal(c, journal)
	f += _expect(c.begin_turn(), "second begin_turn")
	f += _expect(c.get_active_index(RingController.RING_INNER) == inner_idx, "inner orientation persists")
	f += _expect(c.get_active_index(RingController.RING_MIDDLE) == middle_idx, "middle orientation persists")
	f += _expect(c.get_remaining_rotations() == 2, "begin_turn resets remaining to 2")
	f += _expect(not c.can_undo(), "begin_turn clears undo")
	f += _expect(
		journal == PackedStringArray(["rotations_changed:2", "active_runes_changed"]),
		"second begin_turn signal order"
	)
	c.queue_free()
	return f


func _test_visual_position_math() -> int:
	var f := 0
	f += _expect(RingVisuals.get_visual_position_index(0, 0) == 0, "a0 s0 → N")
	f += _expect(RingVisuals.get_visual_position_index(1, 0) == 1, "a0 s1 → W")
	f += _expect(RingVisuals.get_visual_position_index(1, 1) == 0, "a1 s1 → N")
	f += _expect(RingVisuals.get_visual_position_index(2, 1) == 1, "a1 s2 → W")
	f += _expect(RingVisuals.get_visual_position_index(0, 1) == 3, "a1 s0 → E")
	f += _expect(RingVisuals.get_visual_position_index(3, 3) == 0, "a3 s3 → N")
	f += _expect(RingVisuals.SLOT_DIRECTIONS[0] == Vector2.UP, "dir N")
	f += _expect(RingVisuals.SLOT_DIRECTIONS[1] == Vector2.LEFT, "dir W")
	return f


func _test_ring_visuals_setup_and_refresh() -> int:
	var board_scene: PackedScene = load("res://scenes/game/board.tscn")
	var board: BoardManager = board_scene.instantiate()
	root.add_child(board)
	board.initialize(9, Vector2i(4, 4))
	var controller := _make_controller_configured()
	var visuals: RingVisuals = board.get_node("RingVisuals")
	var ok := visuals.setup(controller)
	var f := 0
	f += _expect(ok, "visuals setup")
	var count := 0
	for ring_id in [&"inner", &"middle", &"outer"]:
		for i in range(4):
			var slot := visuals.get_slot_visual(ring_id, i)
			if slot != null:
				count += 1
				f += _expect(slot.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ignore mouse")
	f += _expect(count == 12, "12 visuals")
	# northern actives: visual position index 0 highlighted via modulate
	for ring_id in [&"inner", &"middle", &"outer"]:
		var north := visuals.get_slot_visual(ring_id, 0)
		f += _expect(north != null and north.modulate.v > 0.9, "northern active highlight")
	controller.begin_turn()
	var before_children := visuals.get_child_count()
	controller.try_rotate(&"inner", 1)
	await process_frame
	f += _expect(visuals.get_child_count() == before_children, "no extra nodes on rotate")
	var new_north := visuals.get_slot_visual(&"inner", 1)
	var old_north := visuals.get_slot_visual(&"inner", 0)
	f += _expect(new_north != null and new_north.modulate.v > 0.9, "rotate moves north highlight")
	f += _expect(old_north != null and old_north.modulate.v < 0.9, "old active dimmed")
	f += _expect(visuals.get_slot_visual(&"nope", 0) == null, "unknown ring null")
	f += _expect(visuals.get_slot_visual(&"inner", 9) == null, "bad index null")
	controller.queue_free()
	board.queue_free()
	await process_frame
	return f


func _test_ring_visuals_setup_atomic() -> int:
	var f := 0
	var board_scene: PackedScene = load("res://scenes/game/board.tscn")
	var board: BoardManager = board_scene.instantiate()
	root.add_child(board)
	board.initialize(9, Vector2i(4, 4))
	var visuals: RingVisuals = board.get_node("RingVisuals")

	f += _expect(not visuals.setup(null), "setup null false")

	var unconfigured := RingController.new()
	root.add_child(unconfigured)
	f += _expect(not visuals.setup(unconfigured), "setup unconfigured false")
	f += _expect(visuals.get_slot_visual(&"inner", 0) == null, "failed setup no partial nodes")
	unconfigured.queue_free()

	var controller := _make_controller_configured()
	f += _expect(visuals.setup(controller), "atomic first setup succeeds")
	var count := 0
	for ring_id in [&"inner", &"middle", &"outer"]:
		for i in range(4):
			if visuals.get_slot_visual(ring_id, i) != null:
				count += 1
	f += _expect(count == 12, "12 nodes after success")

	f += _expect(not visuals.setup(null), "null after success returns false")
	var kept := 0
	for ring_id in [&"inner", &"middle", &"outer"]:
		for i in range(4):
			if visuals.get_slot_visual(ring_id, i) != null:
				kept += 1
	f += _expect(kept == 12, "keeps 12 after failed re-setup")

	controller.queue_free()
	board.queue_free()
	await process_frame
	return f


func _swap_enemies_for_counting(game: Node) -> CountingEnemyManager:
	var board: BoardManager = game.get_node("Board")
	var old: Node = board.get_node("Enemies")
	var counting := CountingEnemyManager.new()
	counting.name = "Enemies"
	var idx := old.get_index()
	board.remove_child(old)
	old.free()
	board.add_child(counting)
	board.move_child(counting, idx)
	return counting


func _test_game_controller_begin_turn_journal() -> int:
	var f := 0
	var packed: PackedScene = load("res://scenes/game/game.tscn")
	var game: Node = packed.instantiate()
	_swap_enemies_for_counting(game)

	var journal := PackedStringArray()
	var tm: TurnManager = game.get_node("TurnManager")
	var ring: RingController = game.get_node("RingController")

	tm.phase_changed.connect(func(phase: TurnManager.Phase) -> void:
		journal.append("phase:%s" % TurnManager.Phase.keys()[phase])
	)
	ring.rotations_changed.connect(func(remaining: int) -> void:
		journal.append("rotations_changed:%d" % remaining)
	)
	ring.active_runes_changed.connect(func(_e: RuneData, _s: RuneData, _m: RuneData) -> void:
		journal.append("active_runes_changed")
	)
	tm.turn_started.connect(func(n: int) -> void:
		journal.append("turn_started:%d" % n)
	)
	tm.input_lock_changed.connect(func(locked: bool) -> void:
		journal.append("lock:%s" % ("true" if locked else "false"))
	)

	root.add_child(game)
	await process_frame
	await process_frame

	var expected_start := PackedStringArray([
		"phase:PLAYER_PREPARE",
		"rotations_changed:2",
		"active_runes_changed",
		"turn_started:1",
		"phase:PLAYER_ROTATE",
		"lock:false",
	])
	f += _expect(journal == expected_start, "case18 start journal order")
	f += _expect(_count_prepare_begin_pairs(journal) == 1, "case18 begin_turn once on first prepare")

	var game_controller: GameController = game as GameController
	game_controller._try_end_turn()
	await process_frame

	var expected_second := PackedStringArray([
		"phase:PLAYER_PREPARE",
		"rotations_changed:2",
		"active_runes_changed",
		"turn_started:2",
		"phase:PLAYER_ROTATE",
		"lock:false",
	])
	var second := PackedStringArray()
	var start_idx := -1
	for i in range(journal.size()):
		if journal[i] == "phase:PLAYER_PREPARE" and i > 0:
			start_idx = i
			break
	if start_idx >= 0:
		for i in range(start_idx, mini(start_idx + 6, journal.size())):
			second.append(journal[i])
	f += _expect(second == expected_second, "case18 second turn prepare journal")
	f += _expect(_count_prepare_begin_pairs(journal) == 2, "case18 begin_turn once per player turn")
	f += _expect(tm.get_turn_number() == 2, "case18 turn number 2 after end turn")

	game.queue_free()
	await process_frame
	return f


func _count_prepare_begin_pairs(journal: PackedStringArray) -> int:
	var count := 0
	for i in range(journal.size() - 1):
		if journal[i] == "phase:PLAYER_PREPARE" and journal[i + 1] == "rotations_changed:2":
			count += 1
	return count


func _test_game_controller_reentrant_end_turn() -> int:
	var f := 0
	var packed: PackedScene = load("res://scenes/game/game.tscn")
	var game: Node = packed.instantiate()
	var counting := _swap_enemies_for_counting(game)
	var tm: TurnManager = game.get_node("TurnManager")
	root.add_child(game)
	await process_frame
	await process_frame

	var game_controller: GameController = game as GameController
	tm.input_lock_changed.connect(func(locked: bool) -> void:
		if locked:
			game_controller._try_end_turn()
	)

	var end_btn: Button = game.get_node("CanvasLayer/HUD/EndTurnButton")
	end_btn.pressed.emit()
	f += _expect(counting.step_all_count == 1, "case19 reentrant end turn step_all once")
	f += _expect(tm.get_current_phase() == TurnManager.Phase.PLAYER_ROTATE, "case19 returned to PLAYER_ROTATE")
	f += _expect(tm.can_accept_player_input(), "case19 accepts input again")

	end_btn.pressed.emit()
	f += _expect(counting.step_all_count == 2, "case19 second end turn step_all twice")

	game.queue_free()
	await process_frame
	return f
