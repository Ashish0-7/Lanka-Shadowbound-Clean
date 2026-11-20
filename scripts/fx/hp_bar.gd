class_name HpBar
extends Node2D

var ratio := 1.0
var width := 16.0

func _draw() -> void:
	draw_rect(Rect2(-width / 2 - 1, -1, width + 2, 4), Color(0.05, 0.05, 0.1, 0.9))
	var c := Color(0.3, 0.9, 0.4) if ratio > 0.5 else (Color(1.0, 0.8, 0.2) if ratio > 0.2 else Color(1.0, 0.3, 0.25))
	draw_rect(Rect2(-width / 2, 0, width * clampf(ratio, 0, 1), 2), c)
