extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://scenes/game/game.tscn")
	if packed == null:
		push_error("FAIL: cannot load game.tscn")
		quit(1)
		return
	var game: Node = packed.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	if not (game is GameController):
		push_error("FAIL: root is not GameController")
		quit(1)
		return

	var tm: TurnManager = game.get_node("TurnManager")
	var rings: RingController = game.get_node("RingController")
	var hud: Node = game.get_node("CanvasLayer/HUD")
	if hud.has_node("EnemyTurnButton"):
		push_error("FAIL: EnemyTurnButton present")
		quit(1)
		return

	var lock_journal: PackedStringArray = PackedStringArray()
	tm.input_lock_changed.connect(func(locked: bool) -> void:
		lock_journal.append("lock:%s" % str(locked).to_lower())
	)

	var end_btn: Button = hud.get_node("EndTurnButton")
	var undo_btn: Button = hud.get_node("UndoButton")
	var combo_label: Label = hud.get_node("ComboLabel")
	var inner_left: Button = hud.get_node("RingControls/InnerLeft")
	var inner_right: Button = hud.get_node("RingControls/InnerRight")
	var middle_left: Button = hud.get_node("RingControls/MiddleLeft")
	var middle_right: Button = hud.get_node("RingControls/MiddleRight")
	var outer_left: Button = hud.get_node("RingControls/OuterLeft")
	var outer_right: Button = hud.get_node("RingControls/OuterRight")
	var rotate_btns: Array[Button] = [
		inner_left, inner_right, middle_left, middle_right, outer_left, outer_right,
	]

	var ok := true
	ok = ok and tm.get_current_phase() == TurnManager.Phase.PLAYER_ROTATE
	ok = ok and not end_btn.disabled and not inner_right.disabled and undo_btn.disabled
	ok = ok and rings.get_remaining_rotations() == 2

	var combo0: String = combo_label.text
	inner_right.pressed.emit()
	await process_frame
	ok = ok and combo_label.text != combo0
	ok = ok and rings.get_remaining_rotations() == 1
	ok = ok and not undo_btn.disabled

	undo_btn.pressed.emit()
	await process_frame
	ok = ok and rings.get_remaining_rotations() == 2
	ok = ok and combo_label.text == combo0

	var idx0 := rings.get_active_index(&"inner")
	inner_right.pressed.emit()
	inner_right.pressed.emit()
	await process_frame
	ok = ok and rings.get_remaining_rotations() == 0
	for btn in rotate_btns:
		ok = ok and btn.disabled
	ok = ok and not undo_btn.disabled and not end_btn.disabled

	var enemy: EnemyActor = game.get_node("Board/Enemies").get_child(0)
	var pos0: Vector2i = enemy.grid_position
	end_btn.pressed.emit()
	await process_frame
	ok = ok and lock_journal.has("lock:true") and lock_journal.has("lock:false")
	ok = ok and enemy.grid_position != pos0
	ok = ok and tm.get_current_phase() == TurnManager.Phase.PLAYER_ROTATE
	ok = ok and rings.get_remaining_rotations() == 2
	ok = ok and rings.get_active_index(&"inner") == posmod(idx0 + 2, 4)

	game.queue_free()
	await process_frame
	if ok:
		print("PASS: Stage 3 play smoke")
		quit(0)
	else:
		push_error("FAIL: Stage 3 play smoke")
		quit(1)
