class_name Flicker
extends Node

var light: PointLight2D
var base := 1.0
var t := 0.0
var seed_off := 0.0

func _ready() -> void:
	seed_off = randf() * 100.0

func _process(delta: float) -> void:
	t += delta
	if light:
		light.energy = base * (0.85 + 0.1 * sin(t * 11.0 + seed_off) + 0.05 * sin(t * 23.0 + seed_off * 2.0))
