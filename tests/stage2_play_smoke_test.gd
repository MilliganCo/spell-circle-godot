extends SceneTree

var _saw_button_disabled_in_pipeline: bool = false


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

	var hud: Node = game.get_node("CanvasLayer/HUD")
	if hud.has_node("EnemyTurnButton"):
		push_error("FAIL: EnemyTurnButton still present")
		quit(1)
		return
	if not hud.has_node("EndTurnButton"):
		push_error("FAIL: EndTurnButton missing")
		quit(1)
		return

	var end_btn: Button = hud.get_node("EndTurnButton")
	var turn_label: Label = hud.get_node("TurnLabel")
	var phase_label: Label = hud.get_node("PhaseLabel")
	var defeat_label: Label = hud.get_node("DefeatLabel")
	var turn_manager: TurnManager = game.get_node("TurnManager")
	var player: PlayerActor = game.get_node("Board/Player")
	var enemies: EnemyManager = game.get_node("Board/Enemies")

	if not ("1" in turn_label.text):
		push_error("FAIL: TurnLabel should contain 1 after start")
		quit(1)
		return
	if phase_label.text.find("PLAYER_ROTATE") < 0:
		push_error("FAIL: PhaseLabel should show PLAYER_ROTATE")
		quit(1)
		return

	turn_manager.phase_changed.connect(func(phase: TurnManager.Phase) -> void:
		if phase == TurnManager.Phase.PLAYER_TARGET:
			if end_btn.disabled:
				_saw_button_disabled_in_pipeline = true
	)

	if enemies.get_child_count() < 1:
		push_error("FAIL: no crawler")
		quit(1)
		return
	var enemy: EnemyActor = enemies.get_child(0) as EnemyActor
	print("START enemy=", enemy.grid_position, " hp=", player.health)

	var guard := 0
	while not turn_manager.is_halted() and guard < 40:
		turn_manager.request_end_turn()
		guard += 1
		await process_frame

	print("END enemy=", enemy.grid_position, " hp=", player.health, " turns=", turn_manager.get_turn_number())

	var ok := player.health == 0 \
		and enemy.grid_position == Vector2i(4, 3) \
		and turn_manager.is_halted() \
		and turn_manager.get_current_phase() == TurnManager.Phase.TURN_END \
		and end_btn.disabled \
		and defeat_label.visible \
		and _saw_button_disabled_in_pipeline

	# Further End Turn must no-op
	var tn := turn_manager.get_turn_number()
	turn_manager.request_end_turn()
	ok = ok and turn_manager.get_turn_number() == tn and turn_manager.is_halted()

	if ok:
		print("PASS: Stage 2 play smoke")
		quit(0)
	else:
		push_error("FAIL: Stage 2 play smoke")
		quit(1)
