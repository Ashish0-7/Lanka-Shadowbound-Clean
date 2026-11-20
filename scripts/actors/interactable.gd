class_name Interactable
extends Node2D
## Anything the player can press [F] on.

var kind := "sign"
var uid := ""
var npc_id := ""
var info: Dictionary = {}
var prompt := "Check"
var prompt_height := 0.0
var active := true
var sprite: Sprite2D
var frames: Array = []
var t := 0.0
var blocker: StaticBody2D
var bob := false
var wander_r := 0.0          # NPCs with wander_r > 0 stroll around their home spot
var walk_speed := 14.0
var home := Vector2.INF
var walk_to := Vector2.ZERO
var walk_wait := 1.0
var walking := false
var soul := false
var armed := true

func _ready() -> void:
	add_to_group("interactable")
	t = randf() * 3.0
	match kind:
		"chest":
			prompt = "Open"
			setup_sprite("treasure_chest_closed")
			add_blocker(6)
			if uid != "" and Game.is_opened(uid):
				sprite.texture = Game.tex("treasure_chest_open")
				active = false
		"note":
			prompt = "Read"
			setup_sprite("message_bottle")
			bob = true
			_glint(Color(0.6, 0.9, 1.0))
			if Game.data["notes"].has(info.get("note", "")):
				queue_free()
		"dig":
			prompt = "Dig"
			setup_sprite("treasure_x_mark")
			sprite.offset = Vector2(0, 0)
			z_index = -10
			_glint(Color(1.0, 0.4, 0.3))
			if uid != "" and Game.is_opened(uid):
				queue_free()
		"sign":
			prompt = "Read"
			setup_sprite("wooden_sign")
			add_blocker(4)
		"portal":
			prompt = ""          # no prompt: walking into the opening takes you through
			armed = false        # armed once the player has been clear of it (no bounce on arrival)
			if info.get("beam", false):
				_make_beam()
		"door":
			prompt = "Unlock"
			setup_sprite("hut_door")
			sprite.offset = Vector2(0, 0)
			sprite.modulate = Color(0.75, 0.65, 0.9)
			var b := StaticBody2D.new()
			b.collision_layer = 1
			var cs := CollisionShape2D.new()
			var rs := RectangleShape2D.new(); rs.size = Vector2(info.get("w", 16), info.get("h", 16))
			cs.shape = rs
			b.add_child(cs)
			add_child(b)
			blocker = b
			if uid != "" and Game.is_opened(uid):
				queue_free()
		"pickup_key":
			prompt = "Take"
			setup_sprite(info.get("icon", "golden_key"))
			bob = true
			if uid != "" and Game.is_opened(uid):
				queue_free()
		"lamp":
			prompt = "Examine"
		"pedestal":
			prompt = "Examine"
			setup_sprite("stone_wall")
			sprite.scale = Vector2(0.8, 0.8)
			add_blocker(6)

func setup_sprite(tex_name: String, frame2 := "") -> void:
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.offset = Vector2(0, -8)
		add_child(sprite)
	sprite.texture = Game.tex(tex_name)
	frames = [sprite.texture]
	if frame2 != "":
		frames.append(Game.tex(frame2))

## Turn this NPC into a "good soul": a remembered islander who keeps their own light.
## Warm translucent body, a glowing rim, rising motes, a soft light, and a gentle hover.
func make_soul(glow := Color(0.55, 0.85, 1.0), wander := 24.0) -> void:
	soul = true
	wander_r = wander
	walk_speed = 11.0
	var mat := FX.make_actor_material(true, glow, true)
	mat.set_shader_parameter("shadow", 0.6)
	sprite.material = mat
	sprite.modulate = Color(1.45, 1.45, 1.5, 0.88)  # over-bright so the soul glows
	var l := PointLight2D.new()
	l.texture = FX.light_texture()
	l.texture_scale = 0.7
	l.color = glow
	l.energy = 0.75
	l.position = Vector2(0, -8)
	add_child(l)
	var f := Flicker.new(); f.light = l; f.base = 0.75
	l.add_child(f)
	var motes := CPUParticles2D.new()
	motes.amount = 6
	motes.lifetime = 1.4
	motes.texture = FX.dot_texture()
	motes.scale_amount_min = 0.2; motes.scale_amount_max = 0.45
	motes.gravity = Vector2(0, -12)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(5, 6)
	motes.position = Vector2(0, -6)
	motes.local_coords = false
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 0.9)); g.set_color(1, Color(glow.r, glow.g, glow.b, 0.0))
	motes.color_ramp = g
	add_child(motes)

const PORTAL_R := 13.0

func _portal_check() -> void:
	if Game.main == null or Game.main.busy or Game.main.dialog.is_open():
		return
	var p := get_tree().get_first_node_in_group("player") as PlayerChar
	if p == null or p.state == "dead":
		return
	var d := p.global_position.distance_to(global_position)
	if not armed:
		if d > PORTAL_R + 10.0:
			armed = true
		return
	if d < PORTAL_R:
		armed = false
		_auto_enter(p)

func _auto_enter(p: PlayerChar) -> void:
	var main = Game.main
	var locked: bool = (info.has("req_shards") and Game.shard_count() < int(info["req_shards"])) or (info.has("req_flag") and not Game.flag(info["req_flag"]))
	if locked:
		# step back out of the doorway, then explain why it won't open
		var away := p.global_position - global_position
		away = away.normalized() if away.length() > 0.5 else Vector2.DOWN
		p.global_position += away * 14.0
		p.velocity = Vector2.ZERO
		Sfx.play("cancel")
		await main.say(info.get("locked_lines", ["It won't open."]))
		return
	Sfx.play("portal")
	p.control_enabled = false
	p.velocity = Vector2.ZERO
	main.change_area(info["to"], info.get("spawn", ""))

func _make_beam() -> void:
	var b := BeamFX.new()
	b.name = "Beam"
	add_child(b)
	var l := PointLight2D.new()
	l.texture = FX.light_texture(); l.color = Color(0.7, 0.85, 1.0); l.texture_scale = 1.2; l.energy = 1.0
	add_child(l)
	var motes := CPUParticles2D.new()
	motes.amount = 18; motes.lifetime = 1.6
	motes.texture = FX.dot_texture()
	motes.scale_amount_min = 0.25; motes.scale_amount_max = 0.6
	motes.gravity = Vector2(0, -26)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(7, 2)
	var g := Gradient.new()
	g.set_color(0, Color(0.9, 0.95, 1.0, 0.9)); g.set_color(1, Color(0.5, 0.7, 1.0, 0.0))
	motes.color_ramp = g
	add_child(motes)

func _glint(c: Color) -> void:
	# a faint glimmer so secrets can be spotted in the dark
	var l := PointLight2D.new()
	l.texture = FX.light_texture()
	l.texture_scale = 0.35
	l.color = c
	l.energy = 0.8
	l.position = Vector2(0, -6)
	add_child(l)
	var f := Flicker.new(); f.light = l; f.base = 0.8
	l.add_child(f)

func add_blocker(r: float) -> void:
	if blocker:
		return
	# AnimatableBody2D: a solid body that can move with its owner (wandering NPCs)
	var ab := AnimatableBody2D.new()
	ab.sync_to_physics = false
	blocker = ab
	blocker.collision_layer = 8 if kind == "npc" else 1
	blocker.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new(); sh.radius = r
	cs.shape = sh
	blocker.add_child(cs)
	add_child(blocker)

func _process(delta: float) -> void:
	t += delta
	if kind == "portal":
		_portal_check()
		if has_node("Beam"):
			get_node("Beam").queue_redraw()
	if sprite == null:
		return
	if frames.size() > 1:
		sprite.texture = frames[int(t * 5.0) % frames.size()]
	if bob:
		sprite.position.y = sin(t * 3.0) * 1.5
	if kind == "npc":
		_npc_update(delta)

func _npc_update(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node2D
	var near := p != null and p.global_position.distance_to(global_position) < 40.0
	if home == Vector2.INF:
		home = global_position
		walk_to = home
	walking = false
	if wander_r > 0.0 and not near:
		walk_wait -= delta
		var to := walk_to - global_position
		if to.length() > 2.0:
			var step := to.normalized() * walk_speed * delta
			var a = Game.main.area if Game.main else null
			var nxt := global_position + step
			var blocked: bool = a != null and a.is_solid_px(nxt)
			if not blocked and p and nxt.distance_to(p.global_position) < 13.0:
				blocked = true  # never walk into the player
			if blocked:
				walk_to = global_position
			else:
				global_position = nxt
				walking = true
				if absf(step.x) > 0.01:
					sprite.flip_h = step.x < 0
		elif walk_wait <= 0.0:
			walk_wait = randf_range(1.5, 4.0)
			walk_to = home + Vector2(randf_range(-wander_r, wander_r), randf_range(-wander_r, wander_r) * 0.6)
	if soul:
		# souls hover and drift rather than step
		sprite.position.y = -3.0 - sin(t * 2.2) * 1.5
		sprite.rotation = (sin(t * 4.0) * 0.05) if walking else 0.0
		if not walking and near and absf(p.global_position.x - global_position.x) > 2.0:
			sprite.flip_h = p.global_position.x < global_position.x
	elif walking:
		sprite.position.y = -absf(sin(t * 9.0)) * 1.5
		sprite.rotation = sin(t * 9.0) * 0.06
	else:
		sprite.position.y = -absf(sin(t * 1.6)) * 0.8
		sprite.rotation = 0.0
		if near and absf(p.global_position.x - global_position.x) > 2.0:
			sprite.flip_h = p.global_position.x < global_position.x

func interact(player: PlayerChar) -> void:
	if not active or Game.main == null:
		return
	var main = Game.main
	match kind:
		"npc":
			await Story.talk(npc_id, self, player)
		"sign":
			await main.say(info.get("lines", ["..."]))
		"note":
			var n := Game.note_by_id(info["note"])
			Sfx.play("pickup")
			Game.add_note(info["note"])
			await main.say(["Found a message in a bottle!", "\"%s\"" % n["title"], n["text"], "(Added to your JOURNAL.)"])
			queue_free()
		"chest":
			_open_chest(main)
		"dig":
			if not Game.has_key_item("shovel"):
				await main.say(["A red X is scratched into the ground.", "Something is buried here... You'll need a shovel."])
				return
			active = false
			Sfx.play("dig")
			FX.burst(get_parent(), global_position, Color(0.85, 0.75, 0.5), 14, 60.0)
			await get_tree().create_timer(0.25).timeout
			Sfx.play("dig", 0.8)
			Game.mark_opened(uid)
			_give_loot(main, info.get("loot", {"coins": 15}))
			queue_free()
		"portal":
			await _auto_enter(player)
		"campfire":
			if prompt == "":
				return
			Game.data["hp"] = Game.data["max_hp"]
			Game.data["mp"] = Game.data["max_mp"]
			Game.data["checkpoint"] = {"area": main.area.area_id, "pos": [global_position.x, global_position.y + 16]}
			Game.stats_changed.emit()
			Sfx.play("heal")
			var yes: bool = await main.ask("The fire is warm and you feel rested. Write tonight's entry into Journal %d?" % Game.slot)
			if yes:
				if Game.save_game():
					Sfx.play("select")
					await main.say(["By the firelight, %s writes in Journal %d." % [Game.data["name"], Game.slot]])
		"door":
			if Game.has_key_item("key"):
				Game.add_key_item("key", -1)
				Game.mark_opened(uid)
				Sfx.play("door")
				FX.burst(get_parent(), global_position, Color(0.9, 0.8, 0.4), 16, 60.0)
				await main.say(["Used a Rusted Key.", "The door creaks open..."])
				queue_free()
			else:
				Sfx.play("cancel")
				await main.say(["The door is sealed tight. There's a rusted keyhole."])
		"pickup_key":
			Game.mark_opened(uid)
			Sfx.play("chest")
			_give_loot(main, info.get("loot", {"key_item": "key"}))
			queue_free()
		"lamp", "pedestal":
			await Story.talk(info.get("story", "lamp"), self, player)

func _open_chest(main) -> void:
	active = false
	Game.mark_opened(uid)
	Sfx.play("chest")
	sprite.texture = Game.tex("treasure_chest_open")
	FX.burst(get_parent(), global_position + Vector2(0, -8), Color(1, 0.9, 0.4), 18, 70.0)
	_give_loot(main, info.get("loot", {"coins": 10}))

func _give_loot(main, loot: Dictionary) -> void:
	var lines := []
	if loot.has("coins"):
		for i in int(loot["coins"]):
			Pickup.spawn(main.area, global_position, "coin")
		lines.append("Found %d gold coins!" % int(loot["coins"]))
	if loot.has("item"):
		Game.add_item(loot["item"], int(loot.get("n", 1)))
		lines.append("Found %s x%d!" % [Game.ITEMS[loot["item"]]["name"], int(loot.get("n", 1))])
	if loot.has("key_item"):
		Game.add_key_item(loot["key_item"], 1)
		lines.append("Obtained the %s!" % Game.KEY_ITEMS[loot["key_item"]]["name"])
		if loot["key_item"].ends_with("shard"):
			Sfx.play("shard")
	if loot.has("skill") and not Game.data["skills"].has(loot["skill"]):
		Game.data["skills"].append(loot["skill"])
		lines.append("Learned %s! Press [%s] to use it." % [Game.SKILLS[loot["skill"]]["name"], Game.SKILLS[loot["skill"]]["key"]])
	Game.inventory_changed.emit()
	Game.stats_changed.emit()
	if lines.size() > 0:
		await main.say(lines)
