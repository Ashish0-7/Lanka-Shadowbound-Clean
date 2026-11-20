class_name EnemyChar
extends CharacterBody2D
## Shadow-touched creatures. Telegraphed attacks, knockback, loot.

const TYPES := {
	"shadow_crab": {"tex": ["crab_1", "crab_2"], "hp": 32, "atk": 9, "speed": 46, "xp": 8, "radius": 6.0, "ai": "charger", "aggro": 105.0, "range": 60.0, "coins": [1, 3], "tint": Color(0.55, 0.15, 0.45)},
	"shadow_gull": {"tex": ["seagull_1", "seagull_2"], "hp": 20, "atk": 8, "speed": 75, "xp": 9, "radius": 6.0, "ai": "diver", "aggro": 130.0, "range": 75.0, "coins": [1, 2], "fly": true, "tint": Color(0.35, 0.25, 0.6)},
	"shadow_jelly": {"tex": ["jellyfish_1", "jellyfish_2"], "hp": 26, "atk": 9, "speed": 28, "xp": 10, "radius": 6.0, "ai": "shooter", "aggro": 120.0, "range": 95.0, "coins": [1, 3], "fly": true, "tint": Color(0.35, 0.2, 0.7)},
	"shadow_monkey": {"tex": ["monkey"], "hp": 46, "atk": 12, "speed": 62, "xp": 15, "radius": 6.0, "ai": "leaper", "aggro": 120.0, "range": 85.0, "coins": [2, 4], "tint": Color(0.45, 0.2, 0.5)},
	"shadow_hermit": {"tex": ["hermit_crab"], "hp": 70, "atk": 12, "speed": 30, "xp": 16, "radius": 6.0, "ai": "guard", "aggro": 90.0, "range": 40.0, "coins": [2, 5], "tint": Color(0.3, 0.25, 0.55)},
	"shadow_pirate": {"tex": ["pirate"], "hp": 85, "atk": 16, "speed": 48, "xp": 26, "radius": 7.0, "ai": "brute", "aggro": 115.0, "range": 26.0, "coins": [4, 9], "tint": Color(0.5, 0.12, 0.3)},
	"shadow_dancer": {"tex": ["tribal_dancer"], "hp": 60, "atk": 14, "speed": 55, "xp": 22, "radius": 6.0, "ai": "shooter", "aggro": 125.0, "range": 90.0, "coins": [3, 6], "burst": 3, "tint": Color(0.6, 0.2, 0.2)},
}

var type := "shadow_crab"
var cfg: Dictionary
var area: GameArea
var hp := 10
var max_hp := 10
var radius := 6.0
var dead := false
var is_boss := false
var level_bonus := 0

var sprite: Sprite2D
var shadow_s: Sprite2D
var root: Node2D
var mat: ShaderMaterial
var hpbar: Node2D
var frames: Array = []

var state := "idle"
var state_t := 0.0
var home := Vector2.ZERO
var wander_to := Vector2.ZERO
var attack_cd := 0.0
var flash := 0.0
var anim_t := 0.0
var target_pos := Vector2.ZERO
var leap_from := Vector2.ZERO
var hurt_t := 0.0
var orbit_dir := 1.0
var hp_show_t := 0.0
var did_hit := false
var tex_scale := 1.0

func _ready() -> void:
	cfg = TYPES.get(type, {})
	if cfg.is_empty() and has_method("_boss_cfg"):
		cfg = call("_boss_cfg")
	add_to_group("enemies")
	max_hp = int(cfg["hp"]) + level_bonus * 8
	hp = max_hp
	radius = cfg["radius"]
	home = position
	wander_to = position
	anim_t = randf() * 5.0
	attack_cd = randf_range(0.5, 1.5)
	orbit_dir = 1.0 if randf() < 0.5 else -1.0
	collision_layer = 4
	collision_mask = (0 if cfg.get("fly", false) else 1) | 2 | 4 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new(); sh.radius = radius * 0.7
	cs.shape = sh
	add_child(cs)
	shadow_s = Sprite2D.new(); shadow_s.texture = FX.shadow_texture()
	shadow_s.scale = Vector2(tex_scale, tex_scale)
	add_child(shadow_s)
	root = Node2D.new(); add_child(root)
	for t in cfg["tex"]:
		frames.append(Game.tex(t))
	sprite = Sprite2D.new()
	sprite.texture = frames[0]
	sprite.offset = Vector2(0, -8)
	sprite.scale = Vector2(tex_scale, tex_scale)
	mat = FX.make_actor_material(true, cfg.get("tint", Color(0.42, 0.18, 0.62)), true)
	sprite.material = mat
	root.add_child(sprite)
	if cfg.get("fly", false):
		sprite.offset.y = -14
	hpbar = HpBar.new()
	hpbar.position = Vector2(0, -20 * tex_scale)
	hpbar.visible = false
	add_child(hpbar)
	# wisps
	var w := CPUParticles2D.new()
	w.amount = 4 if not is_boss else 18
	w.lifetime = 1.0
	w.texture = FX.dot_texture()
	w.scale_amount_min = 0.3; w.scale_amount_max = 0.6
	w.gravity = Vector2(0, -14)
	w.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	w.emission_sphere_radius = 5.0 * tex_scale
	w.position = Vector2(0, -6 * tex_scale)
	var g := Gradient.new()
	var tc: Color = cfg.get("tint", Color(0.42, 0.18, 0.62))
	g.set_color(0, Color(tc.r * 1.4, tc.g * 1.2, tc.b * 1.5, 0.8)); g.set_color(1, Color(0.1, 0, 0.2, 0))
	w.color_ramp = g
	root.add_child(w)

func player() -> PlayerChar:
	return area.player if area else null

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0
	did_hit = false

func _physics_process(delta: float) -> void:
	if dead:
		return
	state_t += delta
	anim_t += delta
	attack_cd = maxf(0.0, attack_cd - delta)
	flash = maxf(0.0, flash - delta * 6.0)
	hp_show_t = maxf(0.0, hp_show_t - delta)
	hpbar.visible = hp_show_t > 0.0 and not is_boss
	mat.set_shader_parameter("flash", flash)
	var p := player()
	if p == null or p.state == "dead":
		_idle(delta)
	else:
		_think(delta, p)
	move_and_slide()
	if not cfg.get("fly", false) and area and state != "attack":
		var c := area.cell_of(global_position)
		if area.is_solid_cell(c.x, c.y):
			global_position = home
	_animate(delta)

func _idle(delta: float) -> void:
	if state != "idle" and state != "hurt":
		_set_state("idle")
	if state == "hurt":
		_hurt(delta)
		return
	if position.distance_to(wander_to) < 4.0 or state_t > 4.0:
		state_t = 0.0
		wander_to = home + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		var c := area.cell_of(wander_to)
		if area.is_solid_cell(c.x, c.y) and not cfg.get("fly", false):
			wander_to = position
	var to := wander_to - position
	velocity = velocity.move_toward(to.normalized() * float(cfg["speed"]) * 0.35 if to.length() > 4.0 else Vector2.ZERO, 300 * delta)

func _hurt(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 700 * delta)
	if state_t > hurt_t:
		_set_state("chase")

func _think(delta: float, p: PlayerChar) -> void:
	var to: Vector2 = p.global_position - global_position
	var dist := to.length()
	match state:
		"idle":
			_idle(delta)
			if dist < float(cfg["aggro"]):
				Game.see(type)
				_set_state("chase")
				FX.float_text(area.fx, global_position + Vector2(0, -6), "!", Color(1, 0.4, 0.4))
		"hurt":
			_hurt(delta)
		"chase":
			_chase(delta, p, to, dist)
		"windup":
			velocity = velocity.move_toward(Vector2.ZERO, 900 * delta)
			flash = 0.35 + 0.35 * sin(state_t * 40.0)
			mat.set_shader_parameter("flash_color", Color(1, 0.3, 0.3))
			if state_t >= _windup_time():
				_attack_start(p)
		"attack":
			_attack_update(delta, p)
		"recover":
			velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)
			if state_t > 0.5:
				_set_state("chase")
	if dist > float(cfg["aggro"]) * 2.4 and state == "chase":
		_set_state("idle")
		wander_to = home

func _windup_time() -> float:
	match cfg["ai"]:
		"leaper": return 0.45
		"brute": return 0.5
		"shooter": return 0.4
		"diver": return 0.35
	return 0.38

func _chase(delta: float, p: PlayerChar, to: Vector2, dist: float) -> void:
	var sp := float(cfg["speed"])
	var want := Vector2.ZERO
	match cfg["ai"]:
		"shooter":
			var ideal := float(cfg["range"]) * 0.75
			if dist > ideal + 12.0:
				want = to.normalized()
			elif dist < ideal - 15.0:
				want = -to.normalized()
			want += to.normalized().orthogonal() * orbit_dir * 0.6
		"diver":
			var tang := to.normalized().orthogonal() * orbit_dir
			var radial := to.normalized() * (dist - 55.0) / 40.0
			want = (tang + radial).normalized()
		_:
			want = to.normalized()
	# simple separation from other enemies
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e):
			continue
		var off: Vector2 = global_position - e.global_position
		var l := off.length()
		if l < 14.0 and l > 0.01:
			want += off / l * (14.0 - l) / 14.0
	velocity = velocity.move_toward(want.normalized() * sp if want.length() > 0.01 else Vector2.ZERO, 500 * delta)
	if attack_cd <= 0.0 and dist < float(cfg["range"]):
		target_pos = p.global_position
		_set_state("windup")
		Sfx.play("windup", 1.0 + randf() * 0.2, -6.0)

func _attack_start(p: PlayerChar) -> void:
	_set_state("attack")
	target_pos = p.global_position
	leap_from = global_position
	match cfg["ai"]:
		"charger", "guard":
			velocity = (target_pos - global_position).normalized() * 190.0
		"brute":
			velocity = (target_pos - global_position).normalized() * 120.0
			FX.slash(area.fx, global_position + Vector2(0, -6), (target_pos - global_position).angle(), 22.0, 2.6, Color(1, 0.3, 0.4, 0.9), 7.0, 0.22)
			Sfx.play("swing2", 0.8)
		"leaper":
			FX.telegraph(area.fx, target_pos, 18.0, 0.45)
		"shooter":
			var n := int(cfg.get("burst", 1))
			for i in n:
				var ang := (target_pos - global_position).angle() + (i - (n - 1) / 2.0) * 0.28
				_shoot(Vector2.from_angle(ang) * 105.0)
			Sfx.play("shoot")
		"diver":
			velocity = (target_pos - global_position).normalized() * 230.0

func _attack_update(delta: float, p: PlayerChar) -> void:
	var dmg := int(cfg["atk"]) + level_bonus * 2
	match cfg["ai"]:
		"charger", "diver", "guard":
			velocity = velocity.move_toward(Vector2.ZERO, 260 * delta)
			_contact(p, dmg, 12.0)
			if state_t > 0.45:
				attack_cd = randf_range(1.0, 1.8)
				_set_state("recover")
		"brute":
			velocity = velocity.move_toward(Vector2.ZERO, 500 * delta)
			if state_t < 0.2:
				var c := global_position + (target_pos - global_position).normalized() * 14.0
				if c.distance_to(p.global_position) < 18.0 and not did_hit:
					did_hit = true
					p.take_hit(dmg, global_position, 180.0)
			if state_t > 0.5:
				attack_cd = randf_range(1.2, 2.0)
				_set_state("recover")
		"leaper":
			var k := clampf(state_t / 0.45, 0.0, 1.0)
			global_position = leap_from.lerp(target_pos, k)
			velocity = Vector2.ZERO
			root.position.y = -sin(k * PI) * 26.0
			if k >= 1.0:
				root.position.y = 0
				FX.ring(area.fx, global_position, 26.0, Color(0.8, 0.4, 1.0, 0.8), 0.3)
				FX.dust(area.fx, global_position)
				Sfx.play("slam", 1.3, -4.0)
				Game.shake(2.0)
				if global_position.distance_to(p.global_position) < 22.0:
					p.take_hit(dmg, global_position, 170.0)
				attack_cd = randf_range(1.4, 2.2)
				_set_state("recover")
		"shooter":
			if state_t > 0.3:
				attack_cd = randf_range(1.4, 2.4)
				_set_state("chase")

func _contact(p: PlayerChar, dmg: int, r: float) -> void:
	if not did_hit and global_position.distance_to(p.global_position) < r + radius * 0.5:
		did_hit = true
		p.take_hit(dmg, global_position)

func _shoot(vel: Vector2, dmg := -1, color := Color(0.75, 0.3, 1.0), rad := 4.0) -> Projectile:
	var pr := Projectile.new()
	pr.area = area
	pr.friendly = false
	pr.position = global_position + Vector2(0, -8)
	pr.velocity = vel
	pr.damage = dmg if dmg > 0 else int(cfg["atk"]) + level_bonus * 2
	pr.color = color
	pr.radius = rad
	area.fx.add_child(pr)
	return pr

func take_hit(dmg: int, dir: Vector2, knock: float, crit := false) -> void:
	if dead:
		return
	if cfg["ai"] == "guard" and state != "attack" and state != "recover":
		# shell blocks frontal hits: reduced damage
		var p := player()
		if p and (p.global_position - global_position).dot(velocity) > 0.0:
			dmg = maxi(1, dmg / 3)
			FX.float_text(area.fx, global_position, "BLOCK", Color(0.7, 0.8, 1.0))
	hp -= dmg
	hp_show_t = 3.0
	hpbar.set("ratio", float(hp) / max_hp)
	hpbar.queue_redraw()
	flash = 1.0
	mat.set_shader_parameter("flash_color", Color(1, 1, 1))
	FX.damage_number(area.fx, global_position, dmg, crit)
	FX.burst(area.fx, global_position + Vector2(0, -6), Color(0.75, 0.4, 1.0), 6 if not crit else 14, 70.0)
	Sfx.play("crit" if crit else "hit")
	Game.see(type)
	if hp <= 0:
		_die()
		return
	if not is_boss or knock > 200.0:
		velocity = dir * knock * (0.35 if is_boss else 1.0)
		hurt_t = 0.22 if not is_boss else 0.05
		if not is_boss:
			_set_state("hurt")
			root.position.y = 0

func _die() -> void:
	dead = true
	remove_from_group("enemies")
	Game.defeat(type)
	Game.add_xp(int(cfg["xp"]) + level_bonus * 3)
	Sfx.play("enemy_die")
	FX.burst(area.fx, global_position + Vector2(0, -6), Color(0.6, 0.2, 0.9), 22, 90.0, 0.6, 0.8)
	FX.burst(area.fx, global_position + Vector2(0, -6), Color(1, 1, 1), 8, 50.0, 0.3, 0.5)
	_drop_loot()
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(root, "scale", Vector2(1.4, 0.2), 0.18)
	tw.parallel().tween_property(root, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
	_on_died()

func _on_died() -> void:
	pass

func _drop_loot() -> void:
	var cr: Array = cfg.get("coins", [1, 2])
	var n := randi_range(int(cr[0]), int(cr[1]))
	for i in n:
		Pickup.spawn(area, global_position, "coin")
	var r := randf()
	if r < 0.14:
		Pickup.spawn(area, global_position, "banana")
	elif r < 0.22:
		Pickup.spawn(area, global_position, "mango")
	elif r < 0.27:
		Pickup.spawn(area, global_position, "coconut")
	elif r < 0.29:
		Pickup.spawn(area, global_position, "coconut_drink")

func _animate(_delta: float) -> void:
	if frames.size() > 1:
		sprite.texture = frames[int(anim_t * (8.0 if velocity.length() > 10.0 else 3.0)) % frames.size()]
	if absf(velocity.x) > 5.0 and state != "attack":
		sprite.flip_h = velocity.x < 0
	if cfg.get("fly", false):
		sprite.position.y = sin(anim_t * 3.0) * 2.0
	elif velocity.length() > 10.0 and state != "attack":
		sprite.position.y = -absf(sin(anim_t * 12.0)) * 1.5
		sprite.rotation = sin(anim_t * 12.0) * 0.08
	else:
		sprite.position.y = lerpf(sprite.position.y, 0.0, 0.2)
		sprite.rotation = 0.0
	if state == "windup":
		sprite.scale = Vector2(tex_scale * 1.15, tex_scale * 0.85)
	else:
		sprite.scale = sprite.scale.lerp(Vector2(tex_scale, tex_scale), 0.2)
