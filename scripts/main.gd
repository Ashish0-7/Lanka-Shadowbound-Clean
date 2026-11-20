extends Node
## Root controller: title -> intro -> world; area streaming, transitions, juice, story flow.

var playing := false
var world: Node2D
var area: GameArea
var ui_layer: CanvasLayer
var menu_layer: CanvasLayer
var fade_layer: CanvasLayer
var hud: Hud
var dialog: DialogBox
var menu: LanternMenu
var title: TitleScreen
var fade: ColorRect
var flash: ColorRect
var shake_amt := 0.0
var _hitstop_until := 0
var busy := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.main = self
	randomize()
	world = Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	ui_layer = CanvasLayer.new(); ui_layer.layer = 10
	add_child(ui_layer)
	hud = Hud.new()
	hud.visible = false
	ui_layer.add_child(hud)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(1, 1, 1, 0)
	ui_layer.add_child(flash)
	menu_layer = CanvasLayer.new(); menu_layer.layer = 20
	add_child(menu_layer)
	menu = LanternMenu.new()
	menu_layer.add_child(menu)
	fade_layer = CanvasLayer.new(); fade_layer.layer = 40
	add_child(fade_layer)
	fade = ColorRect.new()
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.color = Color(0, 0, 0, 0)
	fade_layer.add_child(fade)
	var dl := CanvasLayer.new(); dl.layer = 45
	add_child(dl)
	dialog = DialogBox.new()
	dl.add_child(dialog)
	var args := OS.get_cmdline_user_args()
	for a0 in args:
		if a0.begins_with("--") and a0.ends_with("test") or a0 == "--harbourshot":
			Game.test_mode = true
	if "--harbourshot" in args:
		Game.new_game("T")
		_load_area("overworld", "start")
		playing = true
		hud.visible = true
		area.reveal(area.cell_of(area.player.global_position), 30)
		area.player.global_position += Vector2(24, 64)
		area.camera.reset_smoothing()
		area.modulate_node.color = Color(1, 1, 1)
		for i in 40:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var out := ""
		for a2 in args:
			if a2.begins_with("--shots="):
				out = a2.substr(8)
		get_viewport().get_texture().get_image().save_png(out.path_join("harbour.png"))
		# sword-swing frames, facing right then down, zoomed in
		area.camera.zoom = Vector2(4, 4)
		var p := area.player
		var idx := 0
		for dir in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
			p.facing = dir
			p.cam_lead = Vector2.ZERO
			p._start_attack(0)
			for k in 3:
				for f in 3:
					await get_tree().physics_frame
				await RenderingServer.frame_post_draw
				var im := get_viewport().get_texture().get_image()
				var sp: Vector2 = get_viewport().get_canvas_transform() * (p.global_position + Vector2(0, -6))
				sp *= Vector2(im.get_size()) / get_viewport().get_visible_rect().size
				im.get_region(Rect2i(Vector2i(sp) - Vector2i(160, 140), Vector2i(320, 260))).save_png(out.path_join("swing_%d.png" % idx))
				idx += 1
			for f in 30:
				await get_tree().physics_frame
		get_tree().quit()
		return
	if "--nametest" in args:
		show_title()
		await get_tree().create_timer(0.6).timeout
		title._open_slots("new")
		title._open_naming()
		await get_tree().process_frame
		title.chosen.disconnect(_on_title_chosen)
		title.chosen.connect(func(_a, n, s): print("SIGNED NAME=", n, " slot=", s); get_tree().quit())
		for k in [KEY_R, KEY_A, KEY_V, KEY_I, KEY_BACKSPACE, KEY_N, KEY_ENTER]:
			var ev := InputEventKey.new()
			ev.keycode = k; ev.physical_keycode = k; ev.pressed = true
			Input.parse_input_event(ev)
			await get_tree().process_frame
			var up := ev.duplicate(); up.pressed = false
			Input.parse_input_event(up)
			await get_tree().process_frame
		await get_tree().create_timer(0.5).timeout
		print("name test timed out, name_str=", title.name_str)
		get_tree().quit()
		return
	if "--portaltest" in args:
		Game.new_game("T")
		_load_area("overworld", "cave")
		playing = true
		hud.visible = true
		var walk := func(action: String, secs: float) -> void:
			Input.action_press(action)
			var t0 := Time.get_ticks_msec()
			while Time.get_ticks_msec() - t0 < int(secs * 1000.0):
				await get_tree().physics_frame
			Input.action_release(action)
		await get_tree().create_timer(0.5).timeout
		await walk.call("up", 1.5)
		await get_tree().create_timer(1.2).timeout
		print("after walking into cave mouth: area=", area.area_id)
		await walk.call("up", 2.0)
		await get_tree().create_timer(1.2).timeout
		print("after walking into cave exit: area=", area.area_id)
		area.player.global_position = area.spawns["temple"]
		await get_tree().create_timer(0.4).timeout
		await walk.call("up", 1.2)
		await get_tree().create_timer(0.3).timeout
		print("lighthouse (no shards): dialog_open=", dialog.is_open(), " area=", area.area_id)
		get_tree().quit()
		return
	if "--peacetest" in args:
		var shots := ""
		for a2 in args:
			if a2.begins_with("--shots="):
				shots = a2.substr(8)
		Game.new_game("T")
		for s in ["tide_shard", "grove_shard", "ember_shard"]:
			Game.add_key_item(s)
		for b in ["boss:tide_king", "boss:ape_alpha", "boss:nameless"]:
			Game.mark_opened(b)
		_load_area("void_temple", "boss_exit")
		playing = true
		hud.visible = true
		await get_tree().create_timer(0.5).timeout
		play_ending()
		var t0 := Time.get_ticks_msec()
		while (area == null or area.area_id != "overworld" or busy) and Time.get_ticks_msec() - t0 < 60000:
			Input.action_press("ui_ok"); await get_tree().process_frame
			Input.action_release("ui_ok"); await get_tree().create_timer(0.15).timeout
		await get_tree().create_timer(2.5).timeout
		var humans := 0
		for n in get_tree().get_nodes_in_group("interactable"):
			if n.npc_id.begins_with("human_"):
				humans += 1
		print("after ending: area=", area.area_id, " night=", area.night, " player_light=", area.player_light != null,
			" enemies=", get_tree().get_nodes_in_group("enemies").size(), " humans=", humans, " explored=", int(area.explored_ratio() * 100), "%")
		if shots != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shots.path_join("peace_lighthouse.png"))
			area.player.global_position = area.cell_center(OverworldGen.VILLAGE.x, OverworldGen.VILLAGE.y + 3)
			area.camera.reset_smoothing()
			await get_tree().create_timer(3.0).timeout
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shots.path_join("peace_village.png"))
		_load_area("tide_caverns", "entrance")
		await get_tree().create_timer(1.0).timeout
		print("caverns after ending: enemies=", get_tree().get_nodes_in_group("enemies").size(), " dark=", area.dark)
		if shots != "":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shots.path_join("peace_caverns.png"))
		get_tree().quit()
		return
	if "--watertest" in args:
		_watertest()
		return
	if "--autotest" in args:
		_autotest(args)
		return
	show_title()

func _watertest() -> void:
	Game.new_game("T")
	_load_area("overworld", "start")
	playing = true
	for i in 5:
		await get_tree().physics_frame
	var a := area
	var space := a.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	var found := 0
	var hits := 0
	for y in a.H:
		for x in a.W:
			if a.gget(x, y) == "water_shallow" and a.oget(x, y) == "":
				found += 1
				if found % 40 == 0:
					q.position = a.cell_center(x, y)
					q.collision_mask = 1
					if space.intersect_point(q).size() > 0:
						hits += 1
	print("shallow cells sampled: ", found / 40, " colliding: ", hits)
	# walk the player into the sea
	var p := a.player
	Input.action_press("down")
	for i in 240:
		await get_tree().physics_frame
	Input.action_release("down")
	var c := a.cell_of(p.global_position)
	print("player ended on ", a.gget(c.x, c.y), " ", a.oget(c.x, c.y), " solid=", a.is_solid_cell(c.x, c.y))
	get_tree().quit()

# ------------------------------------------------------------------ developer autotest (godot -- --autotest [--shots=DIR])
func _autotest(args: PackedStringArray) -> void:
	var shots := ""
	for a in args:
		if a.begins_with("--shots="):
			shots = a.substr(8)
	var snap := func(name: String) -> void:
		if shots == "":
			return
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(shots.path_join(name + ".png"))
		print("shot ", name)
	var wait := func(sec: float) -> void:
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < int(sec * 1000.0):
			await get_tree().process_frame
	Game.new_game("TESTER")
	var t0 := Time.get_ticks_msec()
	_load_area("overworld", "start")
	print("overworld built in ", Time.get_ticks_msec() - t0, " ms; enemies=", get_tree().get_nodes_in_group("enemies").size())
	playing = true
	hud.visible = true
	await wait.call(1.5)
	await snap.call("01_start_beach")
	# talk to banda via story directly
	Story.talk("banda", null, area.player)
	await wait.call(0.6)
	await snap.call("02_dialog")
	while dialog.is_open():
		Input.action_press("ui_ok"); await get_tree().process_frame
		Input.action_release("ui_ok"); await wait.call(0.05)
	# combat test: spawn crabs next to the player and swing
	for i in 3:
		var e := area.add_enemy("shadow_crab", area.player.global_position + Vector2(30 + i * 8, 0))
		e.level_bonus = 0
	for i in 12:
		Input.action_press("attack"); await get_tree().physics_frame
		Input.action_release("attack"); await wait.call(0.12)
	await snap.call("03_combat")
	Game.data["skills"] = ["whirl", "bolt", "radiant"]
	Game.data["mp"] = 999
	Input.action_press("skill3"); await get_tree().physics_frame; Input.action_release("skill3")
	await wait.call(0.15)
	await snap.call("04_radiance")
	await wait.call(0.8)
	# visit landmarks
	for spot in [["village", OverworldGen.VILLAGE], ["jungle", OverworldGen.GROVE + Vector2i(8, 8)], ["lighthouse", OverworldGen.TEMPLE + Vector2i(0, 3)], ["lagoon", OverworldGen.LAGOON + Vector2i(0, 7)], ["cave", OverworldGen.CAVE + Vector2i(0, 2)]]:
		area.player.global_position = area.cell_center(spot[1].x, spot[1].y)
		area.camera.reset_smoothing()
		await wait.call(1.0)
		await snap.call("05_" + spot[0])
	# menus
	menu.open(); await wait.call(0.3); await snap.call("06_menu")
	menu.sel = 1; await wait.call(0.4); await snap.call("06b_menu_turned")
	for sec in ["map", "satchel", "bestiary", "pages", "explorer", "settings", "save", "title"]:
		menu.open_book(sec); await wait.call(0.5); await snap.call("07_sub_" + sec)
	menu.sub_sel = 2; menu._refresh_text(); await wait.call(0.4); await snap.call("07_sub_title_turn")
	menu.open_book("bestiary"); menu.sub_sel = 3; menu._refresh_text(); await wait.call(0.5); await snap.call("07_sub_bestiary_turned")
	menu.close()
	# grove boss
	area.player.global_position = area.cell_center(OverworldGen.GROVE.x + 3, OverworldGen.GROVE.y + 3)
	await wait.call(2.5)
	await snap.call("11_grove_boss")
	for b in get_tree().get_nodes_in_group("boss"):
		b.take_hit(99999, Vector2.ZERO, 0.0)
	await wait.call(3.0)
	print("grove boss defeated: ", Game.is_opened("boss:ape_alpha"))
	# dungeons
	for d in ["tide_caverns", "void_temple"]:
		t0 = Time.get_ticks_msec()
		_load_area(d, "entrance")
		print(d, " built in ", Time.get_ticks_msec() - t0, " ms; enemies=", get_tree().get_nodes_in_group("enemies").size())
		await wait.call(1.2)
		await snap.call("12_" + d)
		Game.add_key_item("key", 1)
		var boss_exit: Vector2 = area.spawns["boss_exit"]
		area.player.global_position = boss_exit - Vector2(0, 30)
		area.camera.reset_smoothing()
		await wait.call(2.5)
		await snap.call("13_" + d + "_boss")
		for b in get_tree().get_nodes_in_group("boss"):
			b.take_hit(99999, Vector2.ZERO, 0.0)
		await wait.call(3.0)
		print(d, " boss defeated: ", Game.is_opened("boss:" + DungeonGen.CFG[d]["boss"]))
	Game.save_game()
	print("save ok, has_save=", Game.has_save())
	await return_to_title()
	await wait.call(1.0)
	title._open_menu(); await wait.call(0.3); await snap.call("20_title_menu")
	title._open_slots("load"); await wait.call(0.3); await snap.call("21_title_slots")
	title._open_naming(); await wait.call(0.3); await snap.call("22_title_name")
	print("AUTOTEST DONE")
	get_tree().quit()

# ------------------------------------------------------------------ flow
func show_title() -> void:
	playing = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	if area:
		area.queue_free()
		area = null
	hud.visible = false
	title = TitleScreen.new()
	fade_layer.add_child(title)
	fade_layer.move_child(fade, -1)
	title.chosen.connect(_on_title_chosen)
	fade.color.a = 1.0
	_fade_to(0.0, 0.8)

func _on_title_chosen(action: String, pname: String, slot: int) -> void:
	if busy:
		return
	busy = true
	await _fade_to(1.0, 0.5)
	title.queue_free()
	title = null
	if action == "continue" and Game.load_game(slot):
		var pos = Game.data.get("pos")
		_load_area(str(Game.data.get("area", "overworld")), "", Vector2(pos[0], pos[1]) if pos is Array else null)
	else:
		Game.new_game(pname)
		Game.slot = maxi(1, slot)
		await _intro()
		_load_area("overworld", "start")
	busy = false
	playing = true
	hud.visible = true
	await _fade_to(0.0, 0.6)
	if not Game.flag("intro_hint"):
		Game.set_flag("intro_hint")
		toast_msg("Talk to the fisherman  [F]", Color(1, 1, 0.7))

func _intro() -> void:
	Sfx.play_music("title")
	var lines := [
		"Every chart of these waters shows open sea.",
		"No reef. No rock. No island.",
		"And yet, one stormy night, your boat struck sand.",
		"You remember the wave. You remember the cold.",
		"You do not remember why you came.",
	]
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 1.0))
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fade_layer.add_child(lbl)
	for l in lines:
		lbl.text = l
		lbl.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(lbl, "modulate:a", 1.0, 0.6)
		await tw.finished
		var waited := 0.0
		while waited < 2.2:
			await get_tree().process_frame
			waited += get_process_delta_time()
			if Input.is_action_just_pressed("ui_ok"):
				break
		var tw2 := create_tween()
		tw2.tween_property(lbl, "modulate:a", 0.0, 0.4)
		await tw2.finished
	lbl.queue_free()

func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, dur)
	await tw.finished

func return_to_title() -> void:
	busy = true
	get_tree().paused = true
	await _fade_to(1.0, 0.5)
	Sfx.play_music("")
	hud.visible = false
	hud.hide_boss()
	if area:
		area.queue_free()
		area = null
	busy = false
	show_title()

func change_area(id: String, spawn := "", pos = null) -> void:
	if busy:
		return
	busy = true
	get_tree().paused = true
	await _fade_to(1.0, 0.35)
	_load_area(id, spawn, pos)
	get_tree().paused = false
	await _fade_to(0.0, 0.35)
	busy = false

func _load_area(id: String, spawn := "", pos = null) -> void:
	if area:
		area.save_state()
		world.remove_child(area)
		area.queue_free()
		area = null
	hud.hide_boss()
	area = GameArea.new()
	area.name = "Area_" + id
	world.add_child(area)
	if id == "overworld":
		OverworldGen.build(area)
	else:
		DungeonGen.build(area, id)
	var p: Vector2
	if pos is Vector2:
		p = pos
	elif area.spawns.has(spawn):
		p = area.spawns[spawn]
	else:
		p = area.spawns.values()[0]
	area.spawn_player(p)
	Game.data["area"] = id
	hud.set_area(area)
	area.current_region = ""
	Sfx.play_music(area.music)

func sync_area_to_save() -> void:
	if area:
		area.save_state()
		Game.data["area"] = area.area_id
		if area.player:
			Game.data["pos"] = [area.player.global_position.x, area.player.global_position.y]

func overworld_explored() -> float:
	if area and area.area_id == "overworld":
		return area.explored_ratio()
	var s: String = Game.data["explored"].get("overworld", "")
	if s == "":
		return 0.0
	var raw := Marshalls.base64_to_raw(s)
	var n := 0
	for b in raw:
		if b != 0:
			n += 1
	return float(n) / maxf(1.0, raw.size() * 0.55)

func menu_open() -> bool:
	return menu.visible

# ------------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	if Engine.time_scale < 1.0 and Time.get_ticks_msec() >= _hitstop_until:
		Engine.time_scale = 1.0
	if area and area.camera:
		shake_amt = maxf(0.0, shake_amt - delta * 30.0)
		area.camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_amt
	if playing:
		hud.visible = not menu.visible
	if playing and not busy and not dialog.is_open() and not menu.visible:
		if Input.is_action_just_pressed("menu") and area and area.player and area.player.state != "dead":
			menu.open()

func shake(amount: float) -> void:
	shake_amt = minf(10.0, maxf(shake_amt, amount))

func hitstop(dur: float) -> void:
	Engine.time_scale = 0.05
	_hitstop_until = maxi(_hitstop_until, Time.get_ticks_msec() + int(dur * 1000.0))

func flash_screen(c: Color, dur: float) -> void:
	flash.color = c
	var tw := create_tween()
	tw.tween_property(flash, "color:a", 0.0, dur)

func show_banner(text: String) -> void:
	hud.show_banner(text)

func toast_msg(text: String, color := Color.WHITE) -> void:
	hud.toast(text, color)

func say(lines: Array) -> void:
	await dialog.say(lines)

func ask(q: String) -> bool:
	return await dialog.ask(q)

# ------------------------------------------------------------------ bosses
func start_boss(b: BossChar) -> void:
	if not is_instance_valid(b) or b.dead:
		return
	area.boss_active = b
	Sfx.play_music("boss")
	hud.show_boss(b.display, 1.0)
	flash_screen(Color(0.6, 0.1, 0.8, 0.5), 0.5)
	toast_msg("!! %s !!" % b.display, Color(1, 0.5, 0.6))
	b.wake()

func update_boss_bar(b: BossChar) -> void:
	hud.show_boss(b.display, clampf(float(b.hp) / b.max_hp, 0.0, 1.0))

func end_boss() -> void:
	hud.hide_boss()
	if area:
		area.boss_active = null
		var tm := get_tree().create_timer(1.0)
		tm.timeout.connect(func():
			if area:
				var r := area.current_region
				area.current_region = ""
				area._check_region(area.cell_of(area.player.global_position))
				if r == area.current_region:
					Sfx.play_music(area.music if area.dark else "overworld")
		)
	toast_msg("The shadow fades...", Color(0.8, 0.9, 1.0))

# ------------------------------------------------------------------ death
func player_died() -> void:
	if busy:
		return
	busy = true
	Sfx.play_music("")
	await get_tree().create_timer(1.2).timeout
	await _fade_to(1.0, 0.8)
	busy = false
	await dialog.say(["%s was swallowed by the shadows..." % Game.data["name"], "...and woke beside the last warm fire.", "Half the coins slipped away into the dark."])
	busy = true
	Game.data["coins"] = int(Game.data["coins"]) / 2
	Game.data["hp"] = Game.data["max_hp"]
	Game.data["mp"] = Game.data["max_mp"]
	var cp: Dictionary = Game.data["checkpoint"]
	var pos = cp.get("pos")
	_load_area(str(cp.get("area", "overworld")), "start" if not pos is Array else "", Vector2(pos[0], pos[1]) if pos is Array else null)
	Game.stats_changed.emit()
	busy = false
	await _fade_to(0.0, 0.6)

# ------------------------------------------------------------------ ending
func play_ending() -> void:
	busy = true
	Game.set_flag("ending_seen")
	get_tree().paused = true
	Sfx.play("shard")
	flash_screen(Color(1, 1, 0.85, 1.0), 2.5)
	Game.shake(8.0)
	await get_tree().create_timer(2.0).timeout
	Sfx.play_music("ending")
	await _fade_to(1.0, 1.0)
	hud.visible = false
	var lines := [
		"The Great Lamp breathes in. Then it burns.",
		"A beam of old sunlight crosses the sea for the first time in three hundred years.",
		"Below, something without a name turns over in its sleep... and is forgotten.",
		"One by one, the shadows on the shore stop moving. Then they wave. Then they are people.",
		"Far away, a cartographer wakes in the night, takes up a pen, and draws a small island where there was only sea.",
		"Beside it, in tiny letters, she writes a name.",
		"The island's.  And yours:  %s." % Game.data["name"],
		"",
		"Time: %s    Shadows calmed: %d    Pages found: %d/8" % [Game.time_string(), int(Game.data.get("kills", 0)), Game.data["notes"].size()],
		"LANKA: SHADOWBOUND\nThank you for playing.\n\nThe Unknown is yours to discover.",
	]
	var lbl := Label.new()
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	fade_layer.add_child(lbl)
	for l in lines:
		if l == "":
			continue
		lbl.text = l
		lbl.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(lbl, "modulate:a", 1.0, 0.8)
		await tw.finished
		var waited := 0.0
		while waited < 3.2:
			await get_tree().process_frame
			waited += get_process_delta_time()
			if Input.is_action_just_pressed("ui_ok"):
				break
		var tw2 := create_tween()
		tw2.tween_property(lbl, "modulate:a", 0.0, 0.6)
		await tw2.finished
	lbl.queue_free()
	# morning: wake on the island, outside the lighthouse, with the lamp burning
	Game.data["hp"] = Game.data["max_hp"]
	Game.data["mp"] = Game.data["max_mp"]
	_load_area("overworld", "temple")
	Game.data["checkpoint"] = {"area": "overworld", "pos": [area.player.global_position.x, area.player.global_position.y]}
	Game.save_game()
	hud.visible = true
	busy = false
	get_tree().paused = false
	Sfx.play_music("overworld")
	await _fade_to(0.0, 1.5)
	toast_msg("Morning. The island remembers.", Color(1, 0.95, 0.7))
	await get_tree().create_timer(2.2).timeout
	toast_msg("Explore freely — your journey is inscribed.", Color(0.9, 0.95, 1))
