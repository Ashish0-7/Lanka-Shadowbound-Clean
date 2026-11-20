class_name MapView
extends Control
## The chart: explored minimap texture, landmarks, pulsing player marker.
## In parchment mode it is drawn like ink on an old page.

var area: GameArea
var parchment := false
var focus_cell := Vector2i(-1, -1)
var t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	if area == null:
		return
	var sc := minf(size.x / area.W, size.y / area.H)
	var dims := Vector2(area.W, area.H) * sc
	var off := (size - dims) / 2.0
	var unknown := Color(0.80, 0.71, 0.53) if parchment else Color(0.12, 0.13, 0.18)
	var hatch := Color(0.35, 0.25, 0.12, 0.22) if parchment else Color(1, 1, 1, 0.03)
	var ink := Game.C_INK if parchment else Color.WHITE
	draw_rect(Rect2(off, dims), unknown)
	for i in range(0, int(dims.x + dims.y), 5):
		var a := off + Vector2(i, 0)
		var b := off + Vector2(i - dims.y, dims.y)
		# clip the hatch line to the chart rectangle
		if a.x > off.x + dims.x:
			var k := (a.x - (off.x + dims.x))
			a = Vector2(off.x + dims.x, off.y + k)
		if b.x < off.x:
			var k2 := off.x - b.x
			b = Vector2(off.x, off.y + dims.y - k2)
		draw_line(a, b, hatch, 1.0)
	draw_texture_rect(area.mini_tex, Rect2(off, dims), false, Color(1, 0.95, 0.85) if parchment else Color.WHITE)
	for lm in area.landmarks:
		var c: Vector2i = lm["cell"]
		if area.explored[c.y * area.W + c.x] == 0:
			continue
		var p := off + (Vector2(c) + Vector2(0.5, 0.5)) * sc
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)]), Color("8a2a14") if parchment else Game.C_GOLD)
		draw_string(ThemeDB.fallback_font, p + Vector2(6, -3), lm["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
	if area.player:
		var pc := area.cell_of(area.player.global_position)
		var pp := off + (Vector2(pc) + Vector2(0.5, 0.5)) * sc
		var r := 3.0 + sin(t * 5.0) * 1.0
		draw_circle(pp, r + 3.0, Color(0.9, 0.2, 0.1, 0.25))
		draw_circle(pp, r, Color(0.85, 0.15, 0.1))
		draw_string(ThemeDB.fallback_font, pp + Vector2(6, 10), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("a02010") if parchment else Color(1, 0.6, 0.6))
	if focus_cell.x >= 0:
		var fp := off + (Vector2(focus_cell) + Vector2(0.5, 0.5)) * sc
		var rr := 7.0 + 3.0 * absf(sin(t * 3.0))
		draw_arc(fp, rr, 0, TAU, 24, Game.C_GOLD, 1.5)
		draw_line(fp + Vector2(-rr - 4, 0), fp + Vector2(-rr + 1, 0), Game.C_GOLD, 1.0)
		draw_line(fp + Vector2(rr - 1, 0), fp + Vector2(rr + 4, 0), Game.C_GOLD, 1.0)
	draw_rect(Rect2(off, dims), Color("5a3a1a") if parchment else Game.C_BORDER, false, 1.0)
