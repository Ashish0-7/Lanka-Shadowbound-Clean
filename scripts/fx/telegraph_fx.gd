class_name TelegraphFX
extends Node2D
## Ground warning circle that fills up before an attack lands.

var radius := 20.0
var duration := 0.8
var color := Color(1, 0.2, 0.3, 0.5)
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	if t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := t / duration
	var c := color
	c.a = 0.25
	draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.6))
	draw_circle(Vector2.ZERO, radius, c)
	var c2 := color
	c2.a = 0.45 + 0.3 * sin(t * 30.0)
	draw_circle(Vector2.ZERO, radius * k, c2)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(color.r, color.g, color.b, 0.9), 1.5)
