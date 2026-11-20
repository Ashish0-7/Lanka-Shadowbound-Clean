class_name DungeonGen
extends RefCounted
## Room-graph dungeons: a main path to the boss, a side branch holding the key,
## a locked door before the boss, dark rooms lit by torches.

const CW := 16
const CH := 12

const CFG := {
	"tide_caverns": {
		"name": "Tide Caverns", "gw": 4, "gh": 3, "seed": 1201, "floors": ["rock_floor", "wet_stone_floor", "rock_floor"], "wall": "stone_wall",
		"accent": "water_tide_pool", "enemies": ["shadow_crab", "shadow_jelly", "shadow_hermit", "shadow_crab"], "boss": "tide_king",
		"shard": "tide_shard", "notes": ["n5", "n6"], "ambient": Color(0.2, 0.24, 0.36), "exit_to": "cave", "lvl": 1,
		"props": ["barrel", "crate", "anchor", "rock_small", "rock_mossy"], "light": Color(0.5, 0.75, 1.0),
	},
	"void_temple": {
		"name": "Lighthouse Depths", "gw": 4, "gh": 4, "seed": 3307, "floors": ["@temple_floor", "@temple_floor", "volcanic_sand"], "wall": "@wall_top",
		"accent": "@rune_floor", "enemies": ["shadow_pirate", "shadow_dancer", "shadow_monkey", "shadow_hermit", "shadow_dancer"], "boss": "nameless",
		"shard": "ember_shard", "notes": ["n7", "n8"], "ambient": Color(0.17, 0.12, 0.22), "exit_to": "temple", "lvl": 4,
		"props": ["barrel", "crate", "rock_big", "tiki_torch"], "light": Color(0.8, 0.4, 1.0),
	},
}

static func build(a: GameArea, id: String) -> void:
	var c: Dictionary = CFG[id]
	var gw: int = c["gw"]; var gh: int = c["gh"]
	a.setup(id, gw * CW, gh * CH)
	a.display_name = c["name"]
	var peace := Game.flag("ending_seen")
	a.music = "village" if peace else "dungeon"
	a.dark = not peace                   # with the lamp lit, light reaches even down here
	a.ambient = Color(0.78, 0.76, 0.84) if peace else c["ambient"]
	a.reveal_radius = 6
	var rng := RandomNumberGenerator.new()
	rng.seed = c["seed"]
	a.rng = rng
	# ---- room graph
	var start := Vector2i(0, rng.randi_range(0, gh - 1))
	var path: Array = [start]
	var used := {start: true}
	var target_len := gw + gh
	var guard := 0
	while path.size() < target_len and guard < 200:
		guard += 1
		var cur: Vector2i = path[-1]
		var opts := []
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = cur + d
			if n.x >= 0 and n.y >= 0 and n.x < gw and n.y < gh and not used.has(n):
				opts.append(n)
		if opts.is_empty():
			break
		var nxt: Vector2i = opts[rng.randi() % opts.size()]
		path.append(nxt)
		used[nxt] = true
	var links := []  # pairs
	for i in range(path.size() - 1):
		links.append([path[i], path[i + 1]])
	var boss_room: Vector2i = path[-1]
	var branches := []
	for attempt in 30:
		if branches.size() >= 3:
			break
		var idx := rng.randi_range(1, path.size() - 2)
		var base: Vector2i = path[idx]
		var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		dirs.shuffle()
		for d in dirs:
			var n: Vector2i = base + d
			if n.x >= 0 and n.y >= 0 and n.x < gw and n.y < gh and not used.has(n):
				used[n] = true
				links.append([base, n])
				branches.append(n)
				# maybe extend
				var n2: Vector2i = n + d
				if rng.randf() < 0.6 and n2.x >= 0 and n2.y >= 0 and n2.x < gw and n2.y < gh and not used.has(n2):
					used[n2] = true
					links.append([n, n2])
					branches.append(n2)
				break
	# ---- carve rooms
	var rooms := {}
	for r in used:
		var big: bool = r == boss_room
		var rw := CW - 2 if big else rng.randi_range(8, CW - 4)
		var rh := CH - 2 if big else rng.randi_range(6, CH - 4)
		var ox: int = r.x * CW + (CW - rw) / 2
		var oy: int = r.y * CH + (CH - rh) / 2
		var rect := Rect2i(ox, oy, rw, rh)
		rooms[r] = rect
		var floors: Array = c["floors"]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				a.gset(x, y, floors[rng.randi() % floors.size()] if rng.randf() < 0.3 else floors[0])
	# corridors through cell centres (width 3)
	var entrances := []
	for l in links:
		var A: Vector2i = l[0]; var B: Vector2i = l[1]
		var ca := Vector2i(A.x * CW + CW / 2, A.y * CH + CH / 2)
		var cb := Vector2i(B.x * CW + CW / 2, B.y * CH + CH / 2)
		var x0 := mini(ca.x, cb.x); var x1 := maxi(ca.x, cb.x)
		var y0 := mini(ca.y, cb.y); var y1 := maxi(ca.y, cb.y)
		for y in range(y0 - 1, y1 + 2):
			for x in range(x0 - 1, x1 + 2):
				if (ca.y == cb.y and absi(y - ca.y) <= 1) or (ca.x == cb.x and absi(x - ca.x) <= 1):
					if a.gget(x, y) == "@void":
						a.gset(x, y, c["floors"][0])
		if B == boss_room or A == boss_room:
			entrances.append([A if B == boss_room else B, ca if B == boss_room else cb, cb if B == boss_room else ca])
	# walls: void cells next to floor
	var walls := []
	for y in a.H:
		for x in a.W:
			if a.gget(x, y) != "@void":
				continue
			var near := false
			for oy in range(-1, 2):
				for ox in range(-1, 2):
					var g := a.gget(x + ox, y + oy)
					if g != "@void" and g != c["wall"]:
						near = true
			if near:
				walls.append(Vector2i(x, y))
	for w in walls:
		a.gset(w.x, w.y, c["wall"])
	# accents inside normal rooms
	for r in rooms:
		if r == boss_room or r == start:
			continue
		var rect: Rect2i = rooms[r]
		if rng.randf() < 0.6 and rect.size.x > 9:
			var px := rng.randi_range(rect.position.x + 2, rect.end.x - 4)
			var py := rng.randi_range(rect.position.y + 2, rect.end.y - 4)
			for y in range(py, py + 2):
				for x in range(px, px + 2):
					a.gset(x, y, c["accent"])
	# boss room rune circle
	var br: Rect2i = rooms[boss_room]
	var bc := br.get_center()
	for y in range(br.position.y, br.end.y):
		for x in range(br.position.x, br.end.x):
			var d := Vector2(x - bc.x, (y - bc.y) * 1.3).length()
			if absf(d - 5.0) < 0.6:
				a.gset(x, y, "@rune_floor" if id == "void_temple" else "wet_stone_floor")
	# ---- the way out: an opening carved into the entrance room's north wall
	var sr: Rect2i = rooms[start]
	var ex := sr.get_center().x
	var ey := sr.position.y - 1
	var exit_tile := "@stairs_up" if id == "void_temple" else "@cave_exit"
	for x in [ex - 1, ex]:
		a.gset(x, ey, exit_tile)
		if ey - 1 >= 0:
			a.gset(x, ey - 1, exit_tile)   # a two-tile-deep passage so it reads as a way out
		if ey - 2 >= 0:
			a.gset(x, ey - 2, "@void")
	a.finalize()
	if peace:
		a.reveal_all()
	# ---- contents
	var sc := a.cell_center(sr.get_center().x, sr.get_center().y)
	var exit_pos := Vector2(ex * 16, ey * 16 + 8)
	a.spawns["entrance"] = exit_pos + Vector2(0, 30)
	a.add_interactable("portal", exit_pos, "", {"to": "overworld", "spawn": c["exit_to"]})
	var glow := Node2D.new()
	glow.position = exit_pos
	a.entities.add_child(glow)
	a.add_light(glow, Color(0.55, 0.65, 1.0) if id != "void_temple" else Color(0.85, 0.7, 1.0), 1.3, 0.9, false)
	var note_i := 0
	var normal_rooms := []
	for r in used:
		if r != start and r != boss_room:
			normal_rooms.append(r)
	normal_rooms.sort_custom(func(p, q): return path.find(p) < path.find(q))
	var key_room: Vector2i = branches[-1] if branches.size() > 0 else path[1]
	var fire_room: Vector2i = path[mini(2, path.size() - 2)]
	for r in rooms:
		var rect: Rect2i = rooms[r]
		var cc := a.cell_center(rect.get_center().x, rect.get_center().y)
		# torches in the corners
		for corner in [Vector2(rect.position.x + 1, rect.position.y + 1), Vector2(rect.end.x - 2, rect.position.y + 1)]:
			var t := a.add_torch(a.cell_center(int(corner.x), int(corner.y)))
			t.modulate = Color(1, 1, 1)
		if r == start or r == boss_room:
			continue
		# props
		for i in rng.randi_range(1, 4):
			var px := rng.randi_range(rect.position.x + 1, rect.end.x - 2)
			var py := rng.randi_range(rect.position.y + 2, rect.end.y - 2)
			if not a.is_solid_cell(px, py):
				var pr: Array = c["props"]
				a.add_prop(pr[rng.randi() % pr.size()], a.cell_center(px, py), 5.0)
				a.block_cell(px, py)
		if r == fire_room:
			a.add_campfire(cc + Vector2(0, 8))
			continue
		if r == key_room:
			a.add_interactable("chest", cc, "%s:keychest" % id, {"loot": {"key_item": "key", "coins": 10}})
			for i in 2:
				_spawn(a, rng, c, rect, int(c["lvl"]) + 1)
			continue
		if note_i < c["notes"].size() and (branches.has(r) or rng.randf() < 0.5):
			a.add_interactable("note", cc + Vector2(rng.randf_range(-20, 20), 10), "", {"note": c["notes"][note_i]})
			note_i += 1
		elif branches.has(r):
			var loot: Dictionary = [{"item": "mango", "n": 2}, {"item": "coconut_drink"}, {"item": "pearl"}, {"coins": 25}][rng.randi() % 4]
			a.add_interactable("chest", cc, "%s:chest:%d:%d" % [id, r.x, r.y], {"loot": loot})
		var n := rng.randi_range(2, 4)
		for i in n:
			_spawn(a, rng, c, rect, int(c["lvl"]))
	# leftover notes go into the start-adjacent room
	while note_i < c["notes"].size():
		var r: Vector2i = path[1]
		var rect: Rect2i = rooms[r]
		a.add_interactable("note", a.cell_center(rect.get_center().x, rect.get_center().y) + Vector2(16 * note_i, -12), "", {"note": c["notes"][note_i]})
		note_i += 1
	# ---- locked door + boss
	var bc_px := a.cell_center(bc.x, bc.y)
	for en in entrances:
		var from_c: Vector2i = en[1]
		var to_c: Vector2i = en[2]
		var horizontal := from_c.y == to_c.y
		# door at the boss room boundary
		var door_cell := Vector2i.ZERO
		if horizontal:
			var bx := br.position.x - 1 if to_c.x > from_c.x else br.end.x
			door_cell = Vector2i(bx, to_c.y)
		else:
			var by := br.position.y - 1 if to_c.y > from_c.y else br.end.y
			door_cell = Vector2i(to_c.x, by)
		var dp := a.cell_center(door_cell.x, door_cell.y)
		if not Game.is_opened("boss:" + c["boss"]):
			a.add_interactable("door", dp, "%s:bossdoor" % id, {"w": 16 if horizontal else 48, "h": 48 if horizontal else 16})
		a.set_meta("gate_pos", dp)
		a.set_meta("gate_size", Vector2(16, 48) if horizontal else Vector2(48, 16))
	a.spawns["boss_exit"] = bc_px + Vector2(0, 30)
	var arena := Rect2(Vector2(br.position * 16), Vector2(br.size * 16))
	if not Game.is_opened("boss:" + c["boss"]):
		var boss := a.add_boss(c["boss"], bc_px, arena)
		var inner := arena.grow(-28)
		a.triggers.append({"rect": inner, "done": false, "fn": func():
			_close_gate(a)
			if Game.main:
				Game.main.start_boss(boss)
		})
		boss.boss_died.connect(func():
			_open_gate(a)
			if Game.main:
				Game.main.end_boss()
			_reward(a, c, bc_px, id)
		)
	else:
		_reward(a, c, bc_px, id)

static func _spawn(a: GameArea, rng: RandomNumberGenerator, c: Dictionary, rect: Rect2i, lvl: int) -> void:
	if Game.flag("ending_seen"):
		return  # no shadows remain
	for t in 10:
		var px := rng.randi_range(rect.position.x + 1, rect.end.x - 2)
		var py := rng.randi_range(rect.position.y + 1, rect.end.y - 2)
		if not a.is_solid_cell(px, py):
			var en: Array = c["enemies"]
			var e := a.add_enemy(en[rng.randi() % en.size()], a.cell_center(px, py))
			e.level_bonus = lvl
			return

static func _close_gate(a: GameArea) -> void:
	if not a.has_meta("gate_pos"):
		return
	var pos: Vector2 = a.get_meta("gate_pos")
	var size: Vector2 = a.get_meta("gate_size")
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.position = pos
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new(); rs.size = size
	cs.shape = rs
	b.add_child(cs)
	var horizontal := size.y > size.x
	var n := int(maxf(size.x, size.y) / 16.0)
	for i in n:
		var s := Sprite2D.new()
		s.texture = Game.tex("fence_v" if horizontal else "fence_h")
		s.position = Vector2(0, (i - (n - 1) / 2.0) * 16) if horizontal else Vector2((i - (n - 1) / 2.0) * 16, 0)
		s.modulate = Color(0.8, 0.5, 1.0)
		b.add_child(s)
	a.entities.add_child(b)
	a.gates.append(b)
	FX.burst(a.fx, pos, Color(0.8, 0.4, 1.0), 20, 60.0)
	Sfx.play("door", 0.7)

static func _open_gate(a: GameArea) -> void:
	for g in a.gates:
		if is_instance_valid(g):
			FX.burst(a.fx, g.global_position, Color(0.8, 0.4, 1.0), 20, 60.0)
			g.queue_free()
	a.gates.clear()

static func _reward(a: GameArea, c: Dictionary, at: Vector2, id: String) -> void:
	var shard: String = c["shard"]
	var uid := "chest:" + shard
	var ch := a.add_interactable("chest", at, uid, {"loot": {"key_item": shard}})
	if not Game.is_opened(uid):
		var l := a.add_light(ch, Color(1, 0.9, 0.5), 1.4, 1.0)
		l.position = Vector2(0, -8)
	# a column of moonlight opens where the guardian fell: step into it to rise to the surface
	a.add_interactable("portal", at + Vector2(0, -44), "", {"to": "overworld", "spawn": c["exit_to"], "beam": true})
	if id == "void_temple":
		var lamp := a.add_interactable("lamp", at + Vector2(48, -8), "", {"story": "lamp"})
		lamp.setup_sprite("lighthouse_top")
		lamp.sprite.scale = Vector2(2, 2)
		lamp.prompt_height = 16
		lamp.add_blocker(8)
		a.add_light(lamp, Color(1, 0.85, 0.5), 1.6, 0.8)
