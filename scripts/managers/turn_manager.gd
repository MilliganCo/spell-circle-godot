class_name TurnManager
extends Node

enum Phase {
	PLAYER_PREPARE,
	PLAYER_ROTATE,
	PLAYER_TARGET,
	PLAYER_CAST,
	SPELL_RESOLUTION,
	ENEMY_PREPARE,
	ENEMY_ACTION,
	ENVIRONMENT_RESOLUTION,
	TURN_END,
}

signal phase_changed(new_phase: Phase)
signal turn_started(turn_number: int)
signal turn_ended(turn_number: int)
signal input_lock_changed(locked: bool)

var _started: bool = false
var _halted: bool = false
var _input_locked: bool = true
var _turn_number: int = 0
var _current_phase: Phase = Phase.PLAYER_PREPARE
var _setup_done: bool = false
var _enemies: EnemyManager
var _player: PlayerActor


func setup(enemies: EnemyManager, player: PlayerActor) -> void:
	if _started:
		push_warning("TurnManager.setup: already started; ignoring")
		return
	if enemies == null or not is_instance_valid(enemies) \
			or player == null or not is_instance_valid(player):
		push_error("TurnManager.setup: enemies/player invalid")
		return
	_enemies = enemies
	_player = player
	_setup_done = true


func start_run() -> void:
	if not _setup_done or _enemies == null or _player == null:
		push_error("TurnManager.start_run: setup required")
		return
	if _started:
		push_warning("TurnManager.start_run: already started; ignoring")
		return
	_started = true
	_begin_turn()


func request_end_turn() -> void:
	if not can_accept_player_input():
		return
	_set_input_locked(true)
	_set_phase(Phase.PLAYER_TARGET)
	_set_phase(Phase.PLAYER_CAST)
	_set_phase(Phase.SPELL_RESOLUTION)
	_set_phase(Phase.ENEMY_PREPARE)
	_set_phase(Phase.ENEMY_ACTION)
	_enemies.step_all()
	_set_phase(Phase.ENVIRONMENT_RESOLUTION)
	_set_phase(Phase.TURN_END)
	turn_ended.emit(_turn_number)
	if _player.is_dead():
		_halted = true
		return
	_begin_turn()


func can_accept_player_input() -> bool:
	return _started \
		and not _halted \
		and not _input_locked \
		and _current_phase == Phase.PLAYER_ROTATE


func get_turn_number() -> int:
	return _turn_number


func get_current_phase() -> Phase:
	return _current_phase


func is_input_locked() -> bool:
	return _input_locked


func is_halted() -> bool:
	return _halted


func _begin_turn() -> void:
	_set_phase(Phase.PLAYER_PREPARE)
	_turn_number += 1
	turn_started.emit(_turn_number)
	_set_phase(Phase.PLAYER_ROTATE)
	_set_input_locked(false)


func _set_phase(value: Phase) -> void:
	_current_phase = value
	phase_changed.emit(value)


func _set_input_locked(value: bool) -> void:
	if _input_locked == value:
		return
	_input_locked = value
	input_lock_changed.emit(value)
