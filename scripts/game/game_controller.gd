class_name GameController
extends Node

@export var crawler_data: EnemyData

@onready var turn_manager: TurnManager = $TurnManager
@onready var ring_controller: RingController = $RingController
@onready var board: BoardManager = $Board
@onready var ring_visuals: RingVisuals = $Board/RingVisuals
@onready var player: PlayerActor = $Board/Player
@onready var enemies: EnemyManager = $Board/Enemies
@onready var health_label: Label = $CanvasLayer/HUD/HealthLabel
@onready var turn_label: Label = $CanvasLayer/HUD/TurnLabel
@onready var phase_label: Label = $CanvasLayer/HUD/PhaseLabel
@onready var info_label: Label = $CanvasLayer/HUD/InfoLabel
@onready var defeat_label: Label = $CanvasLayer/HUD/DefeatLabel
@onready var combo_label: Label = $CanvasLayer/HUD/ComboLabel
@onready var rotations_label: Label = $CanvasLayer/HUD/RotationsLabel
@onready var undo_button: Button = $CanvasLayer/HUD/UndoButton
@onready var end_turn_button: Button = $CanvasLayer/HUD/EndTurnButton
@onready var btn_inner_left: Button = $CanvasLayer/HUD/RingControls/InnerLeft
@onready var btn_inner_right: Button = $CanvasLayer/HUD/RingControls/InnerRight
@onready var btn_middle_left: Button = $CanvasLayer/HUD/RingControls/MiddleLeft
@onready var btn_middle_right: Button = $CanvasLayer/HUD/RingControls/MiddleRight
@onready var btn_outer_left: Button = $CanvasLayer/HUD/RingControls/OuterLeft
@onready var btn_outer_right: Button = $CanvasLayer/HUD/RingControls/OuterRight


func _ready() -> void:
	defeat_label.visible = false
	board.initialize(9, Vector2i(4, 4))
	_build_cell_visuals()
	player.setup(board)
	enemies.setup(board, player, enemies)
	turn_manager.setup(enemies, player)

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	turn_manager.turn_started.connect(_on_turn_started)
	turn_manager.phase_changed.connect(_on_phase_changed)
	turn_manager.input_lock_changed.connect(_on_input_lock_changed)

	end_turn_button.pressed.connect(_try_end_turn)
	undo_button.pressed.connect(_try_undo)
	btn_inner_left.pressed.connect(func() -> void: _try_ring_rotate(RingController.RING_INNER, -1))
	btn_inner_right.pressed.connect(func() -> void: _try_ring_rotate(RingController.RING_INNER, 1))
	btn_middle_left.pressed.connect(func() -> void: _try_ring_rotate(RingController.RING_MIDDLE, -1))
	btn_middle_right.pressed.connect(func() -> void: _try_ring_rotate(RingController.RING_MIDDLE, 1))
	btn_outer_left.pressed.connect(func() -> void: _try_ring_rotate(RingController.RING_OUTER, -1))
	btn_outer_right.pressed.connect(func() -> void: _try_ring_rotate(RingController.RING_OUTER, 1))

	var starter := StarterRingLayout.build()
	if not ring_controller.setup(starter[&"inner"], starter[&"middle"], starter[&"outer"]):
		push_error("GameController: ring setup failed")
		return

	ring_visuals.position = Vector2(
		(board.center.x + 0.5) * BoardManager.CELL_SIZE_PX,
		(board.center.y + 0.5) * BoardManager.CELL_SIZE_PX
	)
	if not ring_visuals.setup(ring_controller):
		push_error("GameController: ring visuals setup failed")
		return

	ring_controller.active_runes_changed.connect(_on_active_runes_changed)
	ring_controller.rotations_changed.connect(_on_rotations_changed)

	player.place_on_board(Vector2i(4, 4))
	_spawn_initial_crawler()
	info_label.text = "End Turn / Space | Rings Q/E A/D Z/C | Undo BackSpace"
	_refresh_hud()
	_refresh_ring_controls()
	turn_manager.start_run()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("confirm"):
		_try_end_turn()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("undo"):
		_try_undo()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ring_inner_left"):
		_try_ring_rotate(RingController.RING_INNER, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ring_inner_right"):
		_try_ring_rotate(RingController.RING_INNER, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ring_middle_left"):
		_try_ring_rotate(RingController.RING_MIDDLE, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ring_middle_right"):
		_try_ring_rotate(RingController.RING_MIDDLE, 1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ring_outer_left"):
		_try_ring_rotate(RingController.RING_OUTER, -1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ring_outer_right"):
		_try_ring_rotate(RingController.RING_OUTER, 1)
		get_viewport().set_input_as_handled()


func _try_ring_rotate(ring_id: StringName, direction: int) -> void:
	if not turn_manager.can_accept_player_input():
		return
	ring_controller.try_rotate(ring_id, direction)
	_refresh_ring_controls()


func _try_undo() -> void:
	if not turn_manager.can_accept_player_input():
		return
	ring_controller.undo()
	_refresh_ring_controls()


func _try_end_turn() -> void:
	if player.is_dead():
		return
	if not turn_manager.can_accept_player_input():
		return
	turn_manager.request_end_turn()


func _on_turn_started(turn_number: int) -> void:
	turn_label.text = "Ход: %d" % turn_number


func _on_phase_changed(phase: TurnManager.Phase) -> void:
	phase_label.text = "Фаза: %s" % TurnManager.Phase.keys()[phase]
	if phase == TurnManager.Phase.PLAYER_PREPARE:
		if not ring_controller.begin_turn():
			push_error("GameController: ring begin_turn failed")
	_refresh_ring_controls()


func _on_input_lock_changed(_locked: bool) -> void:
	_refresh_ring_controls()


func _on_active_runes_changed(element: RuneData, shape: RuneData, modifier: RuneData) -> void:
	combo_label.text = "%s + %s + %s" % [element.display_name, shape.display_name, modifier.display_name]


func _on_rotations_changed(remaining: int) -> void:
	rotations_label.text = "Вращения: %d" % remaining
	_refresh_ring_controls()


func _refresh_ring_controls() -> void:
	var accepts := turn_manager.can_accept_player_input()
	var can_rot := accepts and ring_controller.can_rotate()
	var can_u := accepts and ring_controller.can_undo()
	btn_inner_left.disabled = not can_rot
	btn_inner_right.disabled = not can_rot
	btn_middle_left.disabled = not can_rot
	btn_middle_right.disabled = not can_rot
	btn_outer_left.disabled = not can_rot
	btn_outer_right.disabled = not can_rot
	undo_button.disabled = not can_u
	end_turn_button.disabled = not accepts or player.is_dead()


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "HP: %d / %d" % [current, maximum]


func _on_player_died() -> void:
	defeat_label.visible = true
	defeat_label.text = "Defeat"
	_refresh_ring_controls()


func _refresh_hud() -> void:
	health_label.text = "HP: %d / %d" % [player.health, player.max_health]


func _spawn_initial_crawler() -> void:
	if crawler_data == null:
		push_error("GameController: crawler_data not assigned")
		return
	var spawn_cell := Vector2i(4, 0)
	if not board.is_inside(spawn_cell) or board.is_occupied(spawn_cell):
		spawn_cell = Vector2i(-1, -1)
		for cell in board.get_edge_spawn_cells(&"north"):
			if not board.is_occupied(cell):
				spawn_cell = cell
				break
	if not board.is_inside(spawn_cell):
		push_error("GameController: no free north-edge spawn cell")
		return
	if enemies.spawn_enemy(crawler_data, spawn_cell) == null:
		push_error("GameController: failed to spawn crawler")


func _build_cell_visuals() -> void:
	var cells_root: Node2D = board.get_node("Cells")
	for y in range(board.board_size):
		for x in range(board.board_size):
			var cell := Vector2i(x, y)
			var rect := ColorRect.new()
			rect.size = Vector2(BoardManager.CELL_SIZE_PX - 2, BoardManager.CELL_SIZE_PX - 2)
			rect.position = Vector2(x * BoardManager.CELL_SIZE_PX + 1, y * BoardManager.CELL_SIZE_PX + 1)
			var state := board.get_cell_state(cell)
			match state.terrain_type:
				&"player_center":
					rect.color = Color(0.25, 0.35, 0.55, 1)
				&"spawn_edge":
					rect.color = Color(0.22, 0.22, 0.28, 1)
				_:
					rect.color = Color(0.15, 0.15, 0.18, 1)
			cells_root.add_child(rect)
