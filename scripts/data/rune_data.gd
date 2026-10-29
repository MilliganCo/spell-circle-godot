class_name RuneData
extends Resource

enum RuneCategory { ELEMENT, SHAPE, MODIFIER }

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var category: RuneCategory
@export var rarity: int = 0
