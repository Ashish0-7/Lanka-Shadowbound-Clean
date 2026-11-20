class_name Critter
extends Node2D
## Harmless ambient wildlife: gulls, fish, turtles, parrots, fireflies.

var type := "seagull"
var area: GameArea
var sprite: Sprite2D
var t := 0.0
var home := Vector2.ZERO
var target := Vector2.ZERO
var speed := 20.0
var frames: Array = []
var frame_t := 0.0
var fi := 0
var flee := false

func _ready() -> void:
	home = position
	t = randf() * 10.0
	sprite = Sprite2D.new()
	add_child(sprite)
	match type:
		"seagull":
			frames = [Game.tex("seagull_1"), Game.tex("seagull_2")]
			speed = 45.0
			sprite.offset = Vector2(0, -28)
			z_index = 30
			var sh := Sprite2D.new(); sh.texture = FX.shadow_texture(); sh.modulate.a = 0.5
			add_child(sh); move_child(sh, 0)
		"fish_blue", "fish_orange":
			frames = [Game.tex(type)]
			speed = 18.0
			sprite.modulate = Color(1, 1, 1, 0.75)
			z_index = -15
		"turtle":
			frames = [Game.tex("turtle_1"), Game.tex("turtle_2")]
			speed = 6.0
			sprite.offset = Vector2(0, -6)
		"parrot":
			frames = [Game.tex("parrot")]
			speed = 0.0
			sprite.offset = Vector2(0, -8)
		"firefly":
			frames = [FX.dot_texture()]
			sprite.scale = Vector2(0.4, 0.4)
			sprite.modulate = Color(0.8, 1.0, 0.4)
			speed = 10.0
			z_index = 30
			var l := PointLight2D.new(); l.texture = FX.light_texture(); l.texture_scale = 0.25; l.color = Color(0.7, 1, 0.3); l.energy = 0.9
			add_child(l)
		"crab_ambient":
			frames = [Game.tex("crab_1"), Game.tex("crab_2")]
			speed = 14.0
			sprite.offset = Vector2(0, -6)
	sprite.texture = frames[0]
	if type in ["turtle", "parrot", "crab_ambient"]:
		var body := AnimatableBody2D.new()
		body.sync_to_physics = false
		body.collision_layer = 8
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new(); sh.radius = 5.0
		cs.shape = sh
		body.add_child(cs)
		add_child(body)
	_pick_target()

func _pick_target() -> void:
	var r := 60.0 if type == "seagull" else 30.0
	for i in 8:
		var p := home + Vector2(randf_range(-r, r), randf_range(-r * 0.6, r * 0.6))
		if type == "seagull" or type == "firefly":
			target = p
			return
		var c := area.cell_of(p)
		var g := area.gget(c.x, c.y)
		var ok := false
		if type.begins_with("fish"):
			ok = g.begins_with("water_shallow") or g == "water_lagoon"
		else:
			ok = not area.is_solid_cell(c.x, c.y)
		if ok:
			target = p
			return
	target = position

func _process(delta: float) -> void:
	t += delta
	frame_t += delta
	if frames.size() > 1 and frame_t > 0.25:
		frame_t = 0.0
		fi = (fi + 1) % frames.size()
		sprite.texture = frames[fi]
	var to := target - position
	if to.length() < 3.0:
		_pick_target()
	else:
		var sp := speed * (3.0 if flee else 1.0)
		var nxt := position + to.normalized() * sp * delta
		var grounded := type != "seagull" and type != "firefly" and not type.begins_with("fish")
		if grounded and area and (area.is_solid_px(nxt) or (area.player and nxt.distance_to(area.player.global_position) < 12.0)):
			_pick_target()
			return
		position = nxt
		if absf(to.x) > 1.0:
			sprite.flip_h = to.x < 0
	match type:
		"firefly":
			sprite.position = Vector2(sin(t * 2.0) * 3.0, cos(t * 1.3) * 4.0 - 10.0)
			sprite.modulate.a = 0.5 + 0.5 * sin(t * 4.0)
		"seagull":
			sprite.position.y = sin(t * 2.0) * 3.0
		"fish_blue", "fish_orange":
			sprite.rotation = sin(t * 6.0) * 0.15
		"parrot":
			sprite.position.y = -absf(sin(t * 3.0)) * 2.0
	if area and area.player and type != "seagull" and type != "firefly":
		var d := area.player.global_position.distance_to(global_position)
		if d < 28.0 and type == "crab_ambient":
			flee = true
			target = position + (global_position - area.player.global_position).normalized() * 40.0
		elif d > 60.0:
			flee = false
