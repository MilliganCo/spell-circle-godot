class_name EnemyData
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export var max_health: int = 1
@export var damage: int = 1
@export var movement_points: int = 1
@export var armor: int = 0
@export var behavior_id: StringName = &"greedy_center"
