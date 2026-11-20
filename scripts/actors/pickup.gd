class_name Pickup
extends Node2D
## Loot that pops out, bounces, then gets magnetised to the player.

var area: GameArea
var kind := "coin"
var vel := Vector2.ZERO
var z := 0.0
var vz := 0.0
var t := 0.0
var spr: Sprite2D
var collected := false

static func spawn(a: GameArea, pos: Vector2, k: String) -> Pickup:
	var p := Pickup.new()
	p.area = a
	p.kind = k
	p.position = pos
	p.vel = Vector2.from_angle(randf() * TAU) * randf_range(20, 55)
	p.vz = randf_range(60, 100)
	a.entities.add_child.call_deferred(p)
	return p

func _ready() -> void:
	var sh := Sprite2D.new(); sh.texture = FX.shadow_texture(); sh.scale = Vector2(0.6, 0.6)
	add_child(sh)
	spr = Sprite2D.new()
	if kind == "coin":
		spr.texture = Game.tex("gold_coin")
		spr.scale = Vector2(0.6, 0.6)
	else:
		spr.texture = Game.tex(Game.ITEMS[kind]["icon"])
		spr.scale = Vector2(0.75, 0.75)
	spr.offset = Vector2(0, -8)
	add_child(spr)

func _physics_process(delta: float) -> void:
	t += delta
	if collected:
		return
	vz -= 300 * delta
	z = maxf(0.0, z + vz * delta)
	if z <= 0.0 and vz < 0:
		vz = -vz * 0.4 if absf(vz) > 20 else 0.0
	var np := position + vel * delta
	if not area.is_solid_px(np):
		position = np
	vel = vel.move_toward(Vector2.ZERO, 90 * delta)
	spr.position.y = -z - (absf(sin(t * 3.0)) * 1.5 if z <= 0.0 else 0.0)
	if t > 0.45 and area.player and area.player.state != "dead":
		var to := area.player.global_position - global_position
		var dist := to.length()
		if dist < 40.0:
			position += to.normalized() * minf(dist, (200.0 - dist * 2.0) * delta)
		if dist < 7.0:
			_collect()
	if t > 60.0:
		queue_free()

func _collect() -> void:
	collected = true
	if kind == "coin":
		Game.data["coins"] = int(Game.data["coins"]) + 1
		Sfx.play("coin", 1.0 + randf() * 0.2, -4.0)
		Game.stats_changed.emit()
	else:
		Game.add_item(kind, 1)
		Sfx.play("pickup")
		FX.float_text(area.fx, global_position, "+ " + Game.ITEMS[kind]["name"], Color(0.7, 1.0, 0.7))
	var tw := create_tween()
	tw.tween_property(spr, "position:y", spr.position.y - 10, 0.15)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.15)
	tw.tween_callback(queue_free)
