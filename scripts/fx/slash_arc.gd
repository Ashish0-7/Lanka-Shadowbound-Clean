class_name SlashArc
extends Node2D

var radius := 18.0
var sweep := 2.4
var color := Color.WHITE
var width := 6.0
var duration := 0.16
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	if t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := t / duration
	var segs := 14
	var a0 := -sweep / 2.0
	var shown := sweep * minf(1.0, k * 2.2)
	var pts := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in segs + 1:
		var f := float(i) / segs
		var a := a0 + shown * f
		var w := width * sin(f * PI) * (1.0 - k * 0.7)
		pts.append(Vector2(cos(a), sin(a)) * radius)
		inner.append(Vector2(cos(a), sin(a)) * (radius - w))
	inner.reverse()
	var poly := pts + inner
	var c := color
	c.a *= (1.0 - k)
	if poly.size() >= 3:
		draw_colored_polygon(poly, c)
		draw_polyline(pts, Color(1, 1, 1, c.a), 1.0)
