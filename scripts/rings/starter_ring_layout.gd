class_name StarterRingLayout
extends RefCounted


static func build() -> Dictionary:
	var fire: RuneData = load("res://resources/runes/elements/fire.tres")
	var ice: RuneData = load("res://resources/runes/elements/ice.tres")
	var lightning: RuneData = load("res://resources/runes/elements/lightning.tres")
	var line: RuneData = load("res://resources/runes/shapes/line.tres")
	var circle: RuneData = load("res://resources/runes/shapes/circle.tres")
	var single_target: RuneData = load("res://resources/runes/shapes/single_target.tres")
	var push: RuneData = load("res://resources/runes/modifiers/push.tres")
	var delay: RuneData = load("res://resources/runes/modifiers/delay.tres")
	var chain: RuneData = load("res://resources/runes/modifiers/chain.tres")
	var inner: Array[RuneData] = [fire, ice, lightning, fire]
	var middle: Array[RuneData] = [line, circle, single_target, line]
	var outer: Array[RuneData] = [push, delay, chain, push]
	return {
		&"inner": inner,
		&"middle": middle,
		&"outer": outer,
	}
