class_name PlayerChar
extends CharacterBody2D
## The warrior. 3-hit combo, dash with i-frames, three skills, procedural animation.

const SPEED := 92.0
const ACCEL := 900.0
const COMBO := [
	{"mult": 1.0, "knock": 90.0, "lunge": 70.0, "arc": 2.4, "dur": 0.20, "reach": 15.0, "radius": 15.0, "snd": "swing"},
	{"mult": 1.15, "knock": 100.0, "lunge": 80.0, "arc": 2.4, "dur": 0.20, "reach": 15.0, "radius": 15.0, "snd": "swing"},
	{"mult": 1.8, "knock": 230.0, "lunge": 150.0, "arc": 3.4, "dur": 0.30, "reach": 18.0, "radius": 19.0, "snd": "swing2"},
]

var area: GameArea
var sprite: Sprite2D
var body_root: Node2D
var shadow: Sprite2D
var pivot: Node2D
var sword: Sprite2D
var arms: Sprite2D
var mat: ShaderMaterial
var prompt_label: Label

var facing := Vector2.DOWN
var aim := Vector2.DOWN
var cam_lead := Vector2.ZERO
var state := "move"
var state_t := 0.0
var combo_i := 0
var combo_window := 0.0
var buffered_attack := false
var hit_ids := {}
var dash_cd := 0.0
var dash_dir := Vector2.ZERO
var invuln := 0.0
var flash := 0.0
var anim_t := 0.0
var step_t := 0.0
var after_t := 0.0
var cooldowns := {"whirl": 0.0, "bolt": 0.0, "radiant": 0.0}
var mp_acc := 0.0
var regen_acc := 0.0
var since_hit := 10.0
var interact_lock := 0.3
var nearest: Interactable = null
var control_enabled := true
var swing_from := 0.0
var last_safe := Vector2.INF
var swing_to := 0.0

func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4 | 8  # world, enemies, npcs: nobody is walked through
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new(); sh.radius = 4.5
	cs.shape = sh
	add_child(cs)
	shadow = Sprite2D.new(); shadow.texture = FX.shadow_texture()
	add_child(shadow)
	body_root = Node2D.new()
	add_child(body_root)
	sprite = Sprite2D.new()
	sprite.texture = Game.tex("hero_sheet")
	sprite.hframes = 7
	sprite.vframes = 3
	sprite.offset = Vector2(0, -8)
	mat = FX.make_actor_material(false)
	sprite.material = mat
	body_root.add_child(sprite)
	pivot = Node2D.new()
	pivot.position = Vector2(0, -6)
	body_root.add_child(pivot)
	# the warrior's arms ride on the same pivot as the blade, so they swing with every cut
	arms = Sprite2D.new()
	arms.texture = Game.tex("hero_arms")
	arms.offset = Vector2(3.5, 0)
	arms.visible = false
	pivot.add_child(arms)
	sword = Sprite2D.new()
	sword.texture = FX.sword_texture()
	sword.offset = Vector2(13, 0)
	sword.visible = false
	pivot.add_child(sword)
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 8)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	prompt_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.2))
	prompt_label.add_theme_constant_override("outline_size", 3)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.size = Vector2(80, 10)
	prompt_label.z_index = 85
	prompt_label.visible = false
	area.fx.add_child.call_deferred(prompt_label)

func _exit_tree() -> void:
	if is_instance_valid(prompt_label):
		prompt_label.queue_free()

func d() -> Dictionary:
	return Game.data

# ------------------------------------------------------------------ main loop
func _physics_process(delta: float) -> void:
	state_t += delta
	anim_t += delta
	dash_cd = maxf(0.0, dash_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	combo_window = maxf(0.0, combo_window - delta)
	interact_lock = maxf(0.0, interact_lock - delta)
	since_hit += delta
	for k in cooldowns:
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	_regen(delta)
	flash = maxf(0.0, flash - delta * 5.0)
	mat.set_shader_parameter("flash", flash)
	var input := Vector2.ZERO
	if control_enabled:
		input = Input.get_vector("left", "right", "up", "down")
	if input.length() > 0.1:
		facing = input.normalized()
	match state:
		"move":
			_state_move(delta, input)
		"attack":
			_state_attack(delta, input)
		"dash":
			_state_dash(delta)
		"skill":
			_state_skill(delta)
		"hurt":
			velocity = velocity.move_toward(Vector2.ZERO, 900 * delta)
			if state_t > 0.18:
				_set_state("move")
		"dead":
			velocity = Vector2.ZERO
	move_and_slide()
	_keep_in_bounds()
	_animate(delta, input)
	cam_lead = cam_lead.lerp(facing * 14.0, delta * 3.0)
	_update_interact()

## Safety net: the player may never stand in water, walls or outside the map.
## If anything ever shoves them there, snap back to the last solid ground.
func _keep_in_bounds() -> void:
	var c := area.cell_of(global_position)
	if area.is_solid_cell(c.x, c.y) and not (area.oget(c.x, c.y) in GameArea.WALKABLE_OVER):
		if last_safe != Vector2.INF:
			global_position = last_safe
			velocity = Vector2.ZERO
	else:
		last_safe = global_position

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0

func _regen(delta: float) -> void:
	mp_acc += delta * (5.0 if since_hit > 3.0 else 2.5)
	if mp_acc >= 1.0:
		var n := int(mp_acc)
		mp_acc -= n
		if d()["mp"] < d()["max_mp"]:
			d()["mp"] = mini(d()["max_mp"], d()["mp"] + n)
			Game.stats_changed.emit()
	if since_hit > 6.0 and d()["hp"] < d()["max_hp"] and state != "dead":
		regen_acc += delta * 2.0
		if regen_acc >= 1.0:
			regen_acc -= 1.0
			d()["hp"] = mini(d()["max_hp"], d()["hp"] + 1)
			Game.stats_changed.emit()

func _state_move(delta: float, input: Vector2) -> void:
	velocity = velocity.move_toward(input * SPEED, ACCEL * delta)
	if not control_enabled or interact_lock > 0.15:
		return  # the key that just closed a dialogue must not also swing or dash
	if Input.is_action_just_pressed("interact") and nearest and interact_lock <= 0.0:
		interact_lock = 0.4
		velocity = Vector2.ZERO
		nearest.interact(self)
		return
	if Input.is_action_just_pressed("attack"):
		if nearest and interact_lock <= 0.0 and nearest.kind == "npc" and not _mouse_attack():
			interact_lock = 0.4
			velocity = Vector2.ZERO
			nearest.interact(self)
			return
		_start_attack(0 if combo_window <= 0.0 else combo_i)
	elif Input.is_action_just_pressed("dash"):
		_start_dash(input)
	elif Input.is_action_just_pressed("skill1"):
		_try_skill("whirl")
	elif Input.is_action_just_pressed("skill2"):
		_try_skill("bolt")
	elif Input.is_action_just_pressed("skill3"):
		_try_skill("radiant")

func _mouse_attack() -> bool:
	return Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)

func _start_attack(i: int) -> void:
	combo_i = i % COMBO.size()
	var c: Dictionary = COMBO[combo_i]
	aim = facing
	if _mouse_attack():
		var m := get_global_mouse_position() - global_position
		if m.length() > 2.0:
			aim = m.normalized()
			facing = aim
	hit_ids.clear()
	_set_state("attack")
	buffered_attack = false
	velocity = aim * float(c["lunge"])
	sword.visible = true
	var base := aim.angle()
	var side := 1.0 if combo_i % 2 == 0 else -1.0
	swing_from = base - side * c["arc"] / 2.0
	swing_to = base + side * c["arc"] / 2.0
	pivot.rotation = swing_from
	Sfx.play(c["snd"], 1.0 + combo_i * 0.08)
	FX.slash(area.fx, global_position + Vector2(0, -6), base, float(c["reach"]) + 4.0, c["arc"], Color(1, 1, 0.9, 0.85) if combo_i < 2 else Color(1, 0.85, 0.4, 0.95), 7.0 if combo_i == 2 else 5.0, c["dur"])
	if side < 0:
		pass

func _state_attack(delta: float, _input: Vector2) -> void:
	var c: Dictionary = COMBO[combo_i]
	var dur: float = c["dur"]
	var k := clampf(state_t / (dur * 0.7), 0.0, 1.0)
	pivot.rotation = lerp_angle(swing_from, swing_to, 1.0 - pow(1.0 - k, 3.0))
	velocity = velocity.move_toward(Vector2.ZERO, 800 * delta)
	if state_t > dur * 0.1 and state_t < dur * 0.7:
		_hit_enemies(global_position + Vector2(0, -5) + aim * float(c["reach"]), float(c["radius"]), int(d()["atk"] * float(c["mult"])), float(c["knock"]), aim, "melee%d" % combo_i)
	if Input.is_action_just_pressed("attack"):
		buffered_attack = true
	if Input.is_action_just_pressed("dash") and state_t > dur * 0.4:
		sword.visible = false
		_start_dash(Input.get_vector("left", "right", "up", "down"))
		return
	if state_t >= dur:
		sword.visible = false
		combo_window = 0.35
		if buffered_attack and combo_i < COMBO.size() - 1:
			_start_attack(combo_i + 1)
		else:
			combo_i = (combo_i + 1) % COMBO.size()
			if combo_i == 0:
				combo_window = 0.0
			_set_state("move")

func _start_dash(input: Vector2) -> void:
	if dash_cd > 0.0:
		return
	dash_dir = input.normalized() if input.length() > 0.1 else facing
	_set_state("dash")
	dash_cd = 0.55
	invuln = maxf(invuln, 0.28)
	velocity = dash_dir * 290.0
	Sfx.play("dash")
	FX.dust(area.fx, global_position)

func _state_dash(delta: float) -> void:
	after_t += delta
	if after_t > 0.025:
		after_t = 0.0
		FX.afterimage(area.fx, sprite)
	velocity = dash_dir * lerpf(290.0, 120.0, state_t / 0.16)
	if state_t >= 0.16:
		_set_state("move")
		velocity = dash_dir * 80.0

# ------------------------------------------------------------------ skills
func has_skill(id: String) -> bool:
	return d()["skills"].has(id)

func _try_skill(id: String) -> void:
	if not has_skill(id):
		FX.float_text(area.fx, global_position, "Not learned", Color(0.8, 0.8, 0.9))
		return
	var s: Dictionary = Game.SKILLS[id]
	if cooldowns[id] > 0.0:
		return
	if d()["mp"] < s["cost"]:
		FX.float_text(area.fx, global_position, "Not enough MP", Color(0.5, 0.7, 1.0))
		Sfx.play("cancel")
		return
	d()["mp"] -= int(s["cost"])
	Game.stats_changed.emit()
	cooldowns[id] = s["cd"]
	hit_ids.clear()
	match id:
		"whirl":
			_set_state("skill")
			set_meta("skill", "whirl")
			sword.visible = true
			Sfx.play("whirl")
		"bolt":
			var dir := facing
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or true:
				var m := get_global_mouse_position() - global_position
				if _mouse_recent() and m.length() > 4.0:
					dir = m.normalized()
			var p := Projectile.new()
			p.area = area
			p.friendly = true
			p.position = global_position + Vector2(0, -6) + dir * 6.0
			p.velocity = dir * 250.0
			p.damage = int(d()["atk"] * 1.7)
			p.color = Color(1.0, 0.85, 0.35)
			p.radius = 5.0
			p.pierce = 2
			area.fx.add_child(p)
			Sfx.play("bolt")
			velocity = -dir * 40.0
		"radiant":
			_set_state("skill")
			set_meta("skill", "radiant")
			Sfx.play("radiant")
			FX.ring(area.fx, global_position + Vector2(0, -6), 80.0, Color(1.0, 0.9, 0.5, 0.9), 0.5, 5.0)
			FX.ring(area.fx, global_position + Vector2(0, -6), 50.0, Color(1, 1, 1, 0.9), 0.3, 3.0)
			FX.burst(area.fx, global_position + Vector2(0, -6), Color(1, 0.95, 0.6), 40, 160.0, 0.6, 0.8)
			Game.shake(5.0)
			_hit_enemies(global_position, 80.0, int(d()["atk"] * 2.6), 260.0, Vector2.ZERO, "radiant", true)
			area.reveal(area.cell_of(global_position), 16)
			if Game.main:
				Game.main.flash_screen(Color(1, 0.95, 0.7, 0.5), 0.35)

var _mouse_t := -10.0
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_mouse_t = Time.get_ticks_msec() / 1000.0

func _mouse_recent() -> bool:
	return Time.get_ticks_msec() / 1000.0 - _mouse_t < 3.0

func _state_skill(delta: float) -> void:
	var sk: String = get_meta("skill", "")
	velocity = velocity.move_toward(Vector2.ZERO, 600 * delta)
	if sk == "whirl":
		pivot.rotation += delta * 28.0
		after_t += delta
		if after_t > 0.05:
			after_t = 0.0
			FX.slash(area.fx, global_position + Vector2(0, -6), pivot.rotation, 22.0, 2.0, Color(0.8, 0.95, 1.0, 0.7), 5.0, 0.12)
		if state_t > 0.05 and state_t < 0.2 and not hit_ids.has("w1"):
			hit_ids.clear(); hit_ids["w1"] = true
			_hit_enemies(global_position + Vector2(0, -5), 30.0, int(d()["atk"] * 1.3), 160.0, Vector2.ZERO, "whirlA")
		if state_t > 0.22 and not hit_ids.has("w2"):
			hit_ids["w2"] = true
			_hit_enemies(global_position + Vector2(0, -5), 30.0, int(d()["atk"] * 1.3), 200.0, Vector2.ZERO, "whirlB")
		if state_t > 0.36:
			sword.visible = false
			_set_state("move")
	else:
		if state_t > 0.25:
			_set_state("move")

# ------------------------------------------------------------------ hitting
func _hit_enemies(center: Vector2, radius: float, dmg: int, knock: float, dir: Vector2, tag: String, big := false) -> void:
	var hit_any := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or e.dead:
			continue
		var key := "%s:%d" % [tag, e.get_instance_id()]
		if hit_ids.has(key):
			continue
		var ep: Vector2 = e.global_position + Vector2(0, -6)
		if ep.distance_to(center) <= radius + e.radius:
			hit_ids[key] = true
			var crit := randf() < 0.12
			var dm := int(dmg * randf_range(0.9, 1.1) * (1.7 if crit else 1.0))
			var kd: Vector2 = dir if dir != Vector2.ZERO else (e.global_position - global_position).normalized()
			e.take_hit(dm, kd, knock, crit)
			hit_any = true
	if hit_any:
		if Game.main:
			Game.main.hitstop(0.06 if not big else 0.1)
		Game.shake(2.5 if not big else 5.0)

func take_hit(dmg: int, from: Vector2, knock := 140.0) -> void:
	if invuln > 0.0 or state == "dead":
		return
	var real := maxi(1, dmg - int(d()["def"]))
	d()["hp"] = maxi(0, d()["hp"] - real)
	Game.stats_changed.emit()
	since_hit = 0.0
	invuln = 0.7
	flash = 1.0
	mat.set_shader_parameter("flash_color", Color(1, 0.3, 0.3))
	FX.damage_number(area.fx, global_position, real, false, Color(1, 0.45, 0.45))
	FX.burst(area.fx, global_position + Vector2(0, -6), Color(1, 0.3, 0.3), 8, 60.0)
	Sfx.play("hurt")
	Game.shake(4.0)
	sword.visible = false
	velocity = (global_position - from).normalized() * knock
	if d()["hp"] <= 0:
		_die()
	else:
		_set_state("hurt")

func _die() -> void:
	_set_state("dead")
	control_enabled = false
	var tw := create_tween()
	tw.tween_property(body_root, "rotation", PI / 2.0, 0.4)
	tw.parallel().tween_property(body_root, "modulate", Color(0.3, 0.2, 0.5, 1), 0.6)
	if Game.main:
		Game.main.player_died()

# ------------------------------------------------------------------ animation
func _animate(delta: float, input: Vector2) -> void:
	if state == "dead":
		return
	var moving := velocity.length() > 20.0
	# sheet rows: 0 down, 1 up, 2 side (flipped for left)
	var look := aim if state == "attack" else facing
	var row := 0
	if absf(look.x) > absf(look.y) * 1.1:
		row = 2
		sprite.flip_h = look.x < 0
	else:
		row = 1 if look.y < 0 else 0
		sprite.flip_h = false
	var col := 0
	if state == "dash":
		col = 2
	elif moving and (state == "move" or state == "hurt"):
		col = 2 + int(anim_t * 10.0) % 4
	elif sword.visible:
		col = 6  # arms-lifted frame; the arm sprite on the pivot does the swinging
	else:
		col = int(anim_t * 1.6) % 2
	sprite.frame = row * 7 + col
	arms.visible = sword.visible
	if sword.visible:
		# lean into the swing: the body twists slightly with the blade
		sprite.skew = sin(pivot.rotation) * 0.08
	if state == "move" and moving:
		var ph := anim_t * 15.0
		sprite.position = Vector2(0, -absf(sin(ph)) * 1.0)
		sprite.rotation = sin(ph) * 0.04
		sprite.scale = Vector2(1.0, 1.0)
		step_t += delta
		if step_t > 0.28:
			step_t = 0.0
			Sfx.play("step", 1.0, -12.0)
			if randf() < 0.5:
				FX.dust(area.fx, global_position + Vector2(randf_range(-2, 2), 0))
	elif state == "dash":
		sprite.rotation = dash_dir.x * 0.3
		sprite.scale = Vector2(1.15, 0.85)
	elif state == "attack":
		sprite.rotation = lerpf(sprite.rotation, aim.x * 0.15, delta * 20.0)
		sprite.scale = sprite.scale.lerp(Vector2(1.1, 0.92), delta * 20.0)
		sprite.position = sprite.position.lerp(Vector2.ZERO, delta * 20.0)
	else:
		sprite.position = sprite.position.lerp(Vector2.ZERO, delta * 15.0)
		sprite.rotation = lerpf(sprite.rotation, 0.0, delta * 15.0)
		var b := 1.0 + sin(anim_t * 3.0) * 0.03
		sprite.scale = sprite.scale.lerp(Vector2(2.0 - b, b), delta * 10.0)
	if not sword.visible:
		sprite.skew = 0.0
	# draw weapon behind when facing up
	pivot.z_index = -1 if (state == "attack" and aim.y < -0.3) else 1
	# invulnerability blink
	if invuln > 0.0 and state != "dash":
		body_root.modulate.a = 0.45 if int(invuln * 20.0) % 2 == 0 else 1.0
	else:
		body_root.modulate.a = 1.0

func _update_interact() -> void:
	var best: Interactable = null
	var bd := 26.0
	for it in get_tree().get_nodes_in_group("interactable"):
		if not is_instance_valid(it) or not it.active:
			continue
		var dd: float = it.global_position.distance_to(global_position)
		if dd < bd:
			bd = dd
			best = it
	nearest = best
	if best and best.prompt != "" and state != "dead":
		prompt_label.visible = true
		prompt_label.text = "[F] " + best.prompt
		prompt_label.global_position = best.global_position + Vector2(-40, -30 - best.prompt_height)
		prompt_label.modulate.a = 0.75 + 0.25 * sin(anim_t * 5.0)
	else:
		prompt_label.visible = false

func revive() -> void:
	_set_state("move")
	control_enabled = true
	body_root.rotation = 0
	body_root.modulate = Color.WHITE
	invuln = 1.5
