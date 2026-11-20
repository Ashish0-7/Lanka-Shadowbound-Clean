class_name BeamFX
extends Node2D
## A soft column of moonlight rising from the floor.

var t := 0.0

func _process(delta: float) -> void:
	t += delta

func _draw() -> void:
	var pulse := 0.75 + 0.25 * sin(t * 2.5)
	for i in 6:
		var w := 14.0 - i * 2.0
		draw_rect(Rect2(-w / 2.0, -64, w, 66), Color(0.65, 0.8, 1.0, 0.06 * pulse))
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.4))
	draw_circle(Vector2.ZERO, 11.0, Color(0.7, 0.85, 1.0, 0.25 * pulse))
	draw_arc(Vector2.ZERO, 11.0 + sin(t * 3.0), 0, TAU, 24, Color(0.85, 0.95, 1.0, 0.7), 1.0)
