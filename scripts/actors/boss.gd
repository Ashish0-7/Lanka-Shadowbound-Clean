class_name BossChar
extends EnemyChar
## Multi-phase bosses with pattern rotation.

signal boss_died

const BOSSES := {
	"tide_king": {"name": "THE TIDE KING", "tex": ["crab_1", "crab_2"], "hp": 520, "atk": 16, "speed": 40, "xp": 180, "radius": 16.0, "ai": "boss", "aggro": 999.0, "range": 999.0, "coins": [20, 30], "scale": 3.0, "tint": Color(0.3, 0.35, 0.8)},
	"ape_alpha": {"name": "GROVE TYRANT", "tex": ["monkey"], "hp": 640, "atk": 19, "speed": 55, "xp": 240, "radius": 15.0, "ai": "boss", "aggro": 999.0, "range": 999.0, "coins": [25, 35], "scale": 2.8, "tint": Color(0.3, 0.55, 0.25)},
	"nameless": {"name": "THE NAMELESS", "tex": ["hero"], "hp": 1200, "atk": 22, "speed": 60, "xp": 500, "radius": 15.0, "ai": "boss", "aggro": 999.0, "range": 999.0, "coins": [0, 0], "scale": 3.2, "fly": true, "tint": Color(0.25, 0.05, 0.35)},
}

var arena := Rect2()
var pattern_i := 0
var phase := 1
var pat := ""
var pat_t := 0.0
var sub_t := 0.0
var sub_n := 0
var charge_dir := Vector2.ZERO
var display := ""
var awake := false

func _init() -> void:
	is_boss = true

func _boss_cfg() -> Dictionary:
	var c: Dictionary = BOSSES[type]
	tex_scale = c["scale"]
	display = c["name"]
	return c

func _ready() -> void:
	super._ready()
	add_to_group("boss")
	collision_mask = (1 if type != "nameless" else 0) | 2 | 8
	if type == "nameless":
		mat.set_shader_parameter("tint", Color(0.18, 0.04, 0.3))
		var l := PointLight2D.new(); l.texture = FX.light_texture(); l.color = Color(0.6, 0.1, 0.9); l.texture_scale = 1.2; l.energy = 0.8
		l.position = Vector2(0, -24)
		root.add_child(l)

func wake() -> void:
	awake = true
	Game.see(type)
	Sfx.play("roar")
	Game.shake(6.0)
	_next_pattern()

func _physics_process(delta: float) -> void:
	if dead:
		return
	anim_t += delta
	flash = maxf(0.0, flash - delta * 6.0)
	mat.set_shader_parameter("flash", flash)
	if not awake:
		_animate(delta)
		return
	var p := player()
	if p == null:
		return
	if phase == 1 and hp < max_hp * 0.5:
		phase = 2
		Sfx.play("roar", 0.8)
		Game.shake(8.0)
		FX.ring(area.fx, global_position, 90.0, Color(1, 0.3, 0.5), 0.6, 5.0)
		if Game.main:
			Game.main.toast_msg("%s is enraged!" % display, Color(1, 0.4, 0.4))
		_set_pat("summon")
	pat_t += delta
	sub_t += delta
	match type:
		"tide_king": _tide_king(delta, p)
		"ape_alpha": _ape(delta, p)
		"nameless": _nameless(delta, p)
	move_and_slide()
	global_position = global_position.clamp(arena.position + Vector2(16, 20), arena.end - Vector2(16, 8))
	_animate(delta)

func _set_pat(p: String) -> void:
	pat = p
	pat_t = 0.0
	sub_t = 0.0
	sub_n = 0
	did_hit = false

func _next_pattern() -> void:
	var seqs := {
		"tide_king": ["charge", "spray", "walk", "charge", "bubbles", "walk"],
		"ape_alpha": ["leap", "leap", "throw", "walk", "quake", "leap", "throw"],
		"nameless": ["spiral", "hands", "teleport", "spiral", "dash", "hands", "teleport"],
	}
	var s: Array = seqs[type]
	pattern_i = (pattern_i + 1) % s.size()
	_set_pat(s[pattern_i])

func _spd() -> float:
	return float(cfg["speed"]) * (1.35 if phase == 2 else 1.0)

func _walk_towards(p: PlayerChar, delta: float, dur := 1.4) -> void:
	velocity = velocity.move_toward((p.global_position - global_position).normalized() * _spd(), 400 * delta)
	if global_position.distance_to(p.global_position) < 28.0 and not did_hit and sub_t > 0.3:
		did_hit = true
		FX.slash(area.fx, global_position + Vector2(0, -10), (p.global_position - global_position).angle(), 30.0, 2.6, Color(1, 0.3, 0.4), 8.0, 0.2)
		if global_position.distance_to(p.global_position) < 34.0:
			p.take_hit(int(cfg["atk"]), global_position, 200.0)
	if pat_t > dur:
		_next_pattern()

func _radial(n: int, speed: float, offset := 0.0, color := Color(0.6, 0.6, 1.0), rad := 4.0) -> void:
	for i in n:
		_shoot(Vector2.from_angle(offset + TAU * i / n) * speed, int(cfg["atk"] * 0.7), color, rad)

# ------------------------------------------------------------------ Tide King
func _tide_king(delta: float, p: PlayerChar) -> void:
	match pat:
		"walk":
			_walk_towards(p, delta)
		"charge":
			if sub_n == 0:
				velocity = Vector2.ZERO
				flash = 0.3 + 0.3 * sin(pat_t * 40.0)
				if pat_t > 0.6:
					charge_dir = (p.global_position - global_position).normalized()
					sub_n = 1; sub_t = 0.0
					Sfx.play("dash", 0.6)
			else:
				velocity = charge_dir * (240.0 if phase == 1 else 300.0)
				_contact(p, int(cfg["atk"]), 22.0)
				if get_slide_collision_count() > 0 or sub_t > 0.9:
					Game.shake(5.0)
					Sfx.play("slam")
					FX.dust(area.fx, global_position)
					if phase == 2:
						_radial(8, 90.0, randf() * TAU, Color(0.5, 0.8, 1.0))
					velocity = Vector2.ZERO
					_next_pattern()
		"spray":
			velocity = Vector2.ZERO
			if sub_t > (0.35 if phase == 1 else 0.22):
				sub_t = 0.0
				sub_n += 1
				_radial(10, 85.0, sub_n * 0.3, Color(0.5, 0.8, 1.0))
				Sfx.play("shoot", 0.7)
			if sub_n >= 4:
				_next_pattern()
		"bubbles":
			velocity = Vector2.ZERO
			if sub_t > 0.15:
				sub_t = 0.0
				sub_n += 1
				var a := (p.global_position - global_position).angle() + randf_range(-0.5, 0.5)
				var pr := _shoot(Vector2.from_angle(a) * 60.0, int(cfg["atk"] * 0.7), Color(0.6, 0.9, 1.0), 5.0)
				pr.accel = 60.0
				Sfx.play("shoot", 1.3, -6)
			if sub_n >= 10:
				_next_pattern()
		"summon":
			velocity = Vector2.ZERO
			if pat_t > 0.5 and sub_n == 0:
				sub_n = 1
				for i in 3:
					var e := area.add_enemy("shadow_crab", global_position + Vector2.from_angle(TAU * i / 3) * 40.0)
					e.level_bonus = 2
			if pat_t > 1.2:
				_next_pattern()

# ------------------------------------------------------------------ Grove Tyrant
func _ape(delta: float, p: PlayerChar) -> void:
	match pat:
		"walk":
			_walk_towards(p, delta, 1.2)
		"leap":
			if sub_n == 0:
				velocity = Vector2.ZERO
				target_pos = p.global_position
				leap_from = global_position
				FX.telegraph(area.fx, target_pos, 34.0, 0.7)
				sub_n = 1; sub_t = 0.0
				Sfx.play("windup", 0.6)
			elif sub_n == 1:
				var k := clampf(sub_t / 0.7, 0.0, 1.0)
				global_position = leap_from.lerp(target_pos, k)
				root.position.y = -sin(k * PI) * 60.0
				if k >= 1.0:
					root.position.y = 0
					sub_n = 2; sub_t = 0.0
					Game.shake(7.0)
					Sfx.play("slam")
					FX.ring(area.fx, global_position, 44.0, Color(0.6, 1.0, 0.4, 0.9), 0.4, 4.0)
					FX.dust(area.fx, global_position)
					if global_position.distance_to(p.global_position) < 38.0:
						p.take_hit(int(cfg["atk"] * 1.2), global_position, 240.0)
					if phase == 2:
						_radial(10, 100.0, 0.0, Color(0.6, 1.0, 0.4))
			elif sub_t > 0.35:
				_next_pattern()
		"throw":
			velocity = Vector2.ZERO
			if sub_t > 0.4:
				sub_t = 0.0
				sub_n += 1
				var n := 3 if phase == 1 else 5
				var base := (p.global_position - global_position).angle()
				for i in n:
					_shoot(Vector2.from_angle(base + (i - (n - 1) / 2.0) * 0.22) * 130.0, int(cfg["atk"] * 0.8), Color(0.75, 0.55, 0.25), 5.0)
				Sfx.play("shoot", 0.8)
			if sub_n >= 3:
				_next_pattern()
		"quake":
			velocity = Vector2.ZERO
			if sub_t > 0.5 and sub_n < 4:
				sub_t = 0.0
				sub_n += 1
				for i in 3:
					var at := p.global_position + Vector2(randf_range(-40, 40), randf_range(-30, 30))
					FX.telegraph(area.fx, at, 18.0, 0.7, Color(0.6, 1, 0.3, 0.5))
					_delayed_blast(at, 18.0, 0.7, int(cfg["atk"]), Color(0.6, 1.0, 0.4))
				Sfx.play("roar", 1.5, -8)
			if pat_t > 3.0:
				_next_pattern()
		"summon":
			velocity = Vector2.ZERO
			if pat_t > 0.4 and sub_n == 0:
				sub_n = 1
				for i in 3:
					var e := area.add_enemy("shadow_monkey", global_position + Vector2.from_angle(TAU * i / 3) * 50.0)
					e.level_bonus = 2
			if pat_t > 1.2:
				_next_pattern()

func _delayed_blast(at: Vector2, r: float, delay: float, dmg: int, color: Color) -> void:
	var tm := get_tree().create_timer(delay, false)
	tm.timeout.connect(func():
		if not is_instance_valid(self) or dead:
			return
		FX.ring(area.fx, at, r + 6.0, color, 0.3, 3.0)
		FX.burst(area.fx, at, color, 10, 70.0)
		Sfx.play("hit", 0.6, -6)
		if area.player and area.player.global_position.distance_to(at) < r + 4.0:
			area.player.take_hit(dmg, at, 160.0)
	)

# ------------------------------------------------------------------ The Nameless
func _nameless(delta: float, p: PlayerChar) -> void:
	match pat:
		"spiral":
			velocity = velocity.move_toward(Vector2.ZERO, 300 * delta)
			if sub_t > (0.12 if phase == 1 else 0.08):
				sub_t = 0.0
				sub_n += 1
				var arms := 3 if phase == 1 else 4
				for i in arms:
					_shoot(Vector2.from_angle(sub_n * 0.32 + TAU * i / arms) * 80.0, int(cfg["atk"] * 0.6), Color(0.75, 0.2, 1.0), 4.0)
				if sub_n % 3 == 0:
					Sfx.play("shoot", 0.6, -8)
			if sub_n >= 30:
				_next_pattern()
		"hands":
			velocity = Vector2.ZERO
			if sub_t > 0.45 and sub_n < 5:
				sub_t = 0.0
				sub_n += 1
				var at := p.global_position + p.velocity * 0.4
				FX.telegraph(area.fx, at, 22.0, 0.75, Color(0.8, 0.2, 1.0, 0.5))
				_delayed_blast(at, 22.0, 0.75, int(cfg["atk"]), Color(0.8, 0.3, 1.0))
			if pat_t > 3.3:
				_next_pattern()
		"teleport":
			if sub_n == 0:
				var tw := create_tween()
				tw.tween_property(root, "modulate:a", 0.0, 0.3)
				sub_n = 1
				Sfx.play("portal", 1.4, -4)
			elif sub_n == 1 and sub_t > 0.35:
				var ang := randf() * TAU
				global_position = (p.global_position + Vector2.from_angle(ang) * 80.0).clamp(arena.position + Vector2(24, 24), arena.end - Vector2(24, 24))
				var tw := create_tween()
				tw.tween_property(root, "modulate:a", 1.0, 0.25)
				sub_n = 2; sub_t = 0.0
			elif sub_n == 2 and sub_t > 0.3:
				_radial(14 if phase == 1 else 20, 95.0, randf() * TAU, Color(0.9, 0.3, 1.0))
				Sfx.play("roar", 1.6, -8)
				_next_pattern()
		"dash":
			if sub_n == 0:
				flash = 0.3 + 0.3 * sin(pat_t * 40.0)
				velocity = Vector2.ZERO
				if pat_t > 0.5:
					charge_dir = (p.global_position - global_position).normalized()
					sub_n = 1; sub_t = 0.0
					Sfx.play("dash", 0.5)
			else:
				velocity = charge_dir * 320.0
				if int(sub_t * 30) % 2 == 0:
					FX.afterimage(area.fx, sprite, Color(0.6, 0.2, 0.9, 0.5))
				_contact(p, int(cfg["atk"]), 24.0)
				if sub_t > 0.55:
					velocity = Vector2.ZERO
					sub_n = 0; pat_t = 0.0
					did_hit = false
					if randf() < 0.5:
						_next_pattern()
		"summon":
			velocity = Vector2.ZERO
			if pat_t > 0.4 and sub_n == 0:
				sub_n = 1
				for t2 in ["shadow_dancer", "shadow_pirate", "shadow_dancer"]:
					var e := area.add_enemy(t2, global_position + Vector2(randf_range(-60, 60), randf_range(-40, 40)))
					e.level_bonus = 3
			if pat_t > 1.2:
				_next_pattern()

func _animate(delta: float) -> void:
	if frames.size() > 1:
		sprite.texture = frames[int(anim_t * (6.0 if velocity.length() > 10.0 else 2.0)) % frames.size()]
	if absf(velocity.x) > 5.0:
		sprite.flip_h = velocity.x < 0
	var b := 1.0 + sin(anim_t * (3.0 if phase == 1 else 6.0)) * 0.04
	sprite.scale = Vector2(tex_scale * (2.0 - b), tex_scale * b)
	if type == "nameless":
		sprite.position.y = -10.0 + sin(anim_t * 1.7) * 4.0
		if randf() < delta * 8.0:
			FX.burst(area.fx, global_position + Vector2(randf_range(-14, 14), randf_range(-40, -5)), Color(0.4, 0.05, 0.6, 0.8), 2, 20.0, 0.8, 0.6)

func take_hit(dmg: int, dir: Vector2, knock: float, crit := false) -> void:
	if not awake or dead:
		return
	super.take_hit(dmg, dir, knock, crit)
	if Game.main:
		Game.main.update_boss_bar(self)

func _die() -> void:
	dead = true
	remove_from_group("enemies")
	Game.defeat(type)
	Game.add_xp(int(cfg["xp"]))
	Game.mark_opened("boss:" + type)
	Sfx.play("roar", 0.6)
	Game.shake(10.0)
	if Game.main:
		Game.main.hitstop(0.25)
	for i in 5:
		var tm := get_tree().create_timer(0.15 * i, false)
		tm.timeout.connect(func():
			if is_instance_valid(self):
				FX.burst(area.fx, global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0)), Color(0.7, 0.3, 1.0), 25, 120.0, 0.7, 0.9)
				Sfx.play("enemy_die", 0.7)
		)
	var cr: Array = cfg.get("coins", [0, 0])
	for i in randi_range(int(cr[0]), int(cr[1])):
		Pickup.spawn(area, global_position, "coin")
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and not e.dead:
			e.take_hit(9999, Vector2.ZERO, 0.0)
	collision_layer = 0
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(root, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func():
		boss_died.emit()
		queue_free()
	)
