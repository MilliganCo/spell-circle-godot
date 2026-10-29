class_name CountingEnemyManager
extends EnemyManager

var step_all_count: int = 0


func step_all() -> void:
	step_all_count += 1
	super.step_all()
