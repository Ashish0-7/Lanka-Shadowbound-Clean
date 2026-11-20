class_name OverworldGen
extends RefCounted
## Builds the island of Lanka-that-was. Seeded noise for the coastline and biomes,
## hand-placed landmarks, paths, bridges, villages and secrets on top.

const W := 128
const H := 96
const START := Vector2i(64, 84)
const VILLAGE := Vector2i(64, 54)
const CAVE := Vector2i(108, 56)
const TEMPLE := Vector2i(98, 16)
const GROVE := Vector2i(24, 22)
const LAGOON := Vector2i(26, 68)

static func build(a: GameArea) -> void:
	a.setup("overworld", W, H)
	a.display_name = "Lanka Isle"
	a.music = "overworld"
	a.reveal_radius = 9
	var peace := Game.flag("ending_seen")
	a.night = not peace
	a.ambient = Color(1.0, 0.98, 0.94) if peace else Color(0.13, 0.15, 0.31)   # sunlight after the ending, moonlight before
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	a.rng = rng
	var noise := FastNoiseLite.new()
	noise.seed = 4242
	noise.frequency = 0.045
	noise.fractal_octaves = 4
	var bnoise := FastNoiseLite.new()
	bnoise.seed = 777
	bnoise.frequency = 0.08

	var lms := [START, VILLAGE, CAVE, TEMPLE, GROVE, LAGOON, Vector2i(64, 70), Vector2i(86, 40), Vector2i(40, 40), Vector2i(90, 64), Vector2i(44, 76), Vector2i(80, 26)]
	var elev := PackedFloat32Array(); elev.resize(W * H)
	for y in H:
		for x in W:
			var nx := (x - W / 2.0) / (W / 2.0)
			var ny := (y - H / 2.0) / (H / 2.0)
			var dd := sqrt(nx * nx * 0.95 + ny * ny * 1.05)
			var e := 0.95 - dd * 1.15 + noise.get_noise_2d(x, y) * 0.38
			for lm in lms:
				var r2 := float((x - lm.x) * (x - lm.x) + (y - lm.y) * (y - lm.y))
				e += 0.5 * exp(-r2 / 120.0)
			elev[y * W + x] = e
	var nodeco := {}
	# ---- base terrain
	for y in H:
		for x in W:
			var e := elev[y * W + x]
			var g := "water_deep"
			if e < -0.05:
				g = "water_deep"
			elif e < 0.08:
				g = "water_shallow"
			elif e < 0.24:
				g = _sand(rng)
			else:
				var bn := bnoise.get_noise_2d(x, y)
				if x < 50 + bn * 8 and y < 46 + bn * 6:
					g = "jungle_floor" if bn > -0.35 else "grass_3"
				elif x > 80 + bn * 6 and y < 36 + bn * 6:
					g = "volcanic_sand" if bn > -0.2 else "rock_floor"
				else:
					g = ["grass_1", "grass_2", "grass_1", "grass_3"][rng.randi() % 4]
					if bn > 0.45:
						g = "grass_flowers"
					elif bn < -0.55:
						g = "dirt"
			a.gset(x, y, g)
	# ---- lagoon
	for y in range(LAGOON.y - 10, LAGOON.y + 11):
		for x in range(LAGOON.x - 12, LAGOON.x + 13):
			var d := Vector2((x - LAGOON.x) / 1.3, y - LAGOON.y).length() + noise.get_noise_2d(x * 3, y * 3) * 1.5
			if d < 5.5:
				a.gset(x, y, "water_lagoon")
			elif d < 8.0:
				a.gset(x, y, ["sand_1", "sand_2", "sand_shells"][rng.randi() % 3])
	# ---- village clearing
	for y in range(VILLAGE.y - 11, VILLAGE.y + 12):
		for x in range(VILLAGE.x - 13, VILLAGE.x + 14):
			var d := Vector2((x - VILLAGE.x) / 1.2, y - VILLAGE.y).length()
			if d < 10.0:
				a.gset(x, y, "dirt" if d < 3.5 else ("grass_flowers" if rng.randf() < 0.25 else "grass_1"))
				nodeco[Vector2i(x, y)] = true
	# ---- grove arena
	for y in range(GROVE.y - 9, GROVE.y + 10):
		for x in range(GROVE.x - 11, GROVE.x + 12):
			var d := Vector2(x - GROVE.x, y - GROVE.y).length()
			if d < 8.5:
				a.gset(x, y, "grass_3" if rng.randf() < 0.7 else "grass_flowers")
				nodeco[Vector2i(x, y)] = true
	# ---- temple plateau of ash
	for y in range(TEMPLE.y - 6, TEMPLE.y + 8):
		for x in range(TEMPLE.x - 8, TEMPLE.x + 9):
			if a.gget(x, y).begins_with("water"):
				continue
			a.gset(x, y, "rock_floor" if Vector2(x - TEMPLE.x, y - TEMPLE.y).length() < 5 else "volcanic_sand")
			nodeco[Vector2i(x, y)] = true
	# ---- the harbour: a smooth crescent bay of sand running down into the sea
	_harbour(a, rng, nodeco)
	# ---- shallow ring: deep water next to land becomes shallow
	var land := func(x: int, y: int) -> bool: return not a.gget(x, y).begins_with("water") and a.inb(x, y)
	for y in H:
		for x in W:
			if a.gget(x, y) == "water_deep":
				var near := false
				for oy in range(-2, 3):
					for ox in range(-2, 3):
						if land.call(x + ox, y + oy):
							near = true
				if near:
					a.gset(x, y, "water_shallow")
	# ---- cliff ridges (decorative solid lines) in highlands
	for i in 22:
		var cx := rng.randi_range(8, W - 8)
		var cy := rng.randi_range(8, H - 8)
		if elev[cy * W + cx] < 0.5:
			continue
		var len := rng.randi_range(3, 7)
		var tex := "cliff_face_sand" if a.gget(cx, cy) == "volcanic_sand" else "cliff_face"
		for k in len:
			var c := Vector2i(cx + k, cy)
			if nodeco.has(c) or a.gget(c.x, c.y).begins_with("water"):
				break
			a.oset(c.x, c.y, tex)
	# ---- cave cliff in east
	for x in range(CAVE.x - 5, CAVE.x + 6):
		for y in range(CAVE.y - 6, CAVE.y + 4):
			if a.gget(x, y).begins_with("water"):
				a.gset(x, y, "sand_2")
			nodeco[Vector2i(x, y)] = true
		for y in range(CAVE.y - 4, CAVE.y - 1):
			a.gset(x, y, "rock_floor")
		a.oset(x, CAVE.y - 2, "cliff_face")
		a.oset(x, CAVE.y - 1, "cliff_face")
	a.oset(CAVE.x, CAVE.y - 1, "@cave_mouth")
	a.oset(CAVE.x - 1, CAVE.y - 1, "@cave_mouth")
	# ---- lighthouse (stone tower) with door
	for x in range(TEMPLE.x - 2, TEMPLE.x + 3):
		for y in range(TEMPLE.y - 3, TEMPLE.y + 1):
			a.oset(x, y, "stone_wall")
	a.oset(TEMPLE.x, TEMPLE.y, "@cave_mouth")
	# ---- village huts
	var huts := [Vector2i(-9, -7), Vector2i(6, -8), Vector2i(-10, 3), Vector2i(7, 3)]
	for h in huts:
		var o: Vector2i = VILLAGE + h
		for yy in 3:
			for xx in 3:
				var name := "hut_roof_thatch"
				if yy == 0 and xx == 1:
					name = "hut_roof_top"
				elif yy == 2:
					name = "hut_door" if xx == 1 else "hut_window"
				elif yy == 1:
					name = "hut_roof_thatch"
				a.oset(o.x + xx, o.y + yy, name)
	# ---- paths
	var path_cells := {}
	_path(a, rng, START + Vector2i(0, -4), VILLAGE + Vector2i(0, 4), path_cells)
	_path(a, rng, VILLAGE + Vector2i(5, 0), CAVE + Vector2i(0, 1), path_cells)
	_path(a, rng, VILLAGE + Vector2i(2, -6), TEMPLE + Vector2i(0, 2), path_cells)
	_path(a, rng, VILLAGE + Vector2i(-5, -3), GROVE + Vector2i(4, 4), path_cells)
	_path(a, rng, VILLAGE + Vector2i(-6, 3), LAGOON + Vector2i(6, -2), path_cells)
	for c in path_cells:
		nodeco[c] = true
	# ---- the pier: a straight jetty from the sand into the bay with a T-shaped head
	var px := START.x + 5
	var first := -1
	for y in range(START.y, H - 1):
		if a.gget(px, y).begins_with("water"):
			first = y
			break
	if first > 0:
		var last := mini(first + 5, H - 2)
		for y in range(first - 1, last + 1):
			a.oset(px, y, "dock_v")
		for x in range(px - 2, px + 3):
			a.oset(x, last, "dock_h")
		a.set_meta("pier_head", Vector2i(px, last))
	# ---- shoreline autotile
	_shore(a)
	# wet sand near water
	for y in H:
		for x in W:
			var g := a.gget(x, y)
			# a continuous band of wet sand right behind the surf line (no random speckles)
			if g.begins_with("sand_") and g != "sand_wet" and not nodeco.has(Vector2i(x, y)):
				for o in [Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, -2)]:
					var n2 := a.gget(x + o.x, y + o.y)
					if n2.begins_with("water_shallow") or n2.begins_with("water_deep"):
						if a.gget(x + o.x / 2, y + o.y / 2).begins_with("shore"):
							a.gset(x, y, "sand_wet")
							break
	# ---- tide pools sprinkled on beaches
	for i in 14:
		var c := Vector2i(rng.randi_range(4, W - 4), rng.randi_range(4, H - 4))
		if a.gget(c.x, c.y).begins_with("sand") and not nodeco.has(c) and not path_cells.has(c):
			a.gset(c.x, c.y, "water_tide_pool")

	a.finalize()
	a.compute_reachable(START)
	if peace:
		a.reveal_all()   # nothing on the island is unknown any more
	_landmarks(a, rng)
	_decorate(a, rng, nodeco)
	_populate(a, rng, nodeco)
	a.regions = [
		{"rect": Rect2i(START.x - 16, START.y - 9, 32, 20), "name": "Driftwood Shore", "music": "overworld"},
		{"rect": Rect2i(VILLAGE.x - 13, VILLAGE.y - 11, 27, 23), "name": "Hollow Village", "music": "village"},
		{"rect": Rect2i(GROVE.x - 10, GROVE.y - 9, 21, 19), "name": "Tyrant's Clearing", "music": "jungle"},
		{"rect": Rect2i(LAGOON.x - 13, LAGOON.y - 10, 26, 20), "name": "Mirror Lagoon", "music": "village"},
		{"rect": Rect2i(TEMPLE.x - 10, TEMPLE.y - 8, 21, 17), "name": "The Great Lamp" if peace else "The Dark Lighthouse", "music": "village" if peace else "dungeon"},
		{"rect": Rect2i(0, 0, 52, 48), "name": "Whispering Jungle", "music": "jungle"},
		{"rect": Rect2i(80, 0, 48, 38), "name": "Ashen Heights", "music": "dungeon"},
		{"rect": Rect2i(90, 42, 38, 30), "name": "Tide Cliffs", "music": "overworld"},
	]
	if peace:
		for r in a.regions:
			if r["music"] == "dungeon" or r["music"] == "jungle":
				r["music"] = "overworld"
	a.landmarks = [
		{"cell": START, "name": "Shore"}, {"cell": VILLAGE, "name": "Village"}, {"cell": CAVE, "name": "Caverns"},
		{"cell": TEMPLE, "name": "Lighthouse"}, {"cell": GROVE, "name": "Clearing"}, {"cell": LAGOON, "name": "Lagoon"},
	]

static func _sand(rng: RandomNumberGenerator) -> String:
	var r := rng.randf()
	if r < 0.78:
		return "sand_1"
	if r < 0.96:
		return "sand_2"
	return "sand_shells"

## The starting harbour: a crescent bay. The coastline is a smooth curve, the beach is one
## continuous sweep of sand from the grass down to the surf, and the sea beyond is clear.
static func _harbour(a: GameArea, rng: RandomNumberGenerator, nodeco: Dictionary) -> void:
	var half := 18
	for x in range(START.x - half, START.x + half + 1):
		var dx := float(x - START.x) / half
		var coast := START.y + 5 - int(round(3.0 * dx * dx))       # waterline curves up at the bay's arms
		var top := START.y - 6 + int(round(2.0 * dx * dx))         # where grass gives way to sand
		for y in range(top, H):
			if not a.inb(x, y):
				continue
			var c := Vector2i(x, y)
			nodeco[c] = true
			if y <= coast:
				a.gset(x, y, _sand(rng))
			elif y <= coast + 3:
				a.gset(x, y, "water_shallow")
			else:
				a.gset(x, y, "water_deep")
		# soften the grass edge just above the beach
		for y in range(top - 2, top):
			if a.inb(x, y) and not a.gget(x, y).begins_with("water"):
				a.gset(x, y, "grass_1")
				nodeco[Vector2i(x, y)] = true

static func _path(a: GameArea, rng: RandomNumberGenerator, from: Vector2i, to: Vector2i, cells: Dictionary) -> void:
	var p := Vector2(from)
	var target := Vector2(to)
	var guard := 0
	var wobble := rng.randf() * 10.0
	while p.distance_to(target) > 1.0 and guard < 600:
		guard += 1
		var dir := (target - p).normalized()
		dir = dir.rotated(sin(guard * 0.15 + wobble) * 0.55)
		p += dir * 0.7
		var c := Vector2i(roundi(p.x), roundi(p.y))
		for o in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var q: Vector2i = c + o
			if not a.inb(q.x, q.y):
				continue
			var g := a.gget(q.x, q.y)
			var ov := a.oget(q.x, q.y)
			if ov.begins_with("hut") or ov == "stone_wall" or ov == "@cave_mouth":
				continue
			if ov.begins_with("cliff"):
				if q.y >= CAVE.y - 2 and q.y <= CAVE.y - 1 and absi(q.x - CAVE.x) < 6:
					continue
				a.oset(q.x, q.y, "")
			if g.begins_with("water"):
				a.oset(q.x, q.y, "boardwalk_h" if absf(dir.x) > absf(dir.y) else "boardwalk_v")
			else:
				a.gset(q.x, q.y, "dirt_path")
			cells[q] = true

static func _shore(a: GameArea) -> void:
	var updates := {}
	var water := func(x: int, y: int) -> bool:
		var g := a.gget(x, y)
		return g == "water_shallow" or g == "water_deep" or g == "water_lagoon"
	for y in a.H:
		for x in a.W:
			var g := a.gget(x, y)
			if not (g.begins_with("sand") or g == "dirt_path"):
				continue
			if g == "dirt_path":
				continue
			var n: bool = water.call(x, y - 1)
			var s: bool = water.call(x, y + 1)
			var e: bool = water.call(x + 1, y)
			var w: bool = water.call(x - 1, y)
			var t := ""
			if n and e: t = "shore_inner_ne"
			elif n and w: t = "shore_inner_nw"
			elif s and e: t = "shore_inner_se"
			elif s and w: t = "shore_inner_sw"
			elif n: t = "shore_north"
			elif s: t = "shore_south"
			elif e: t = "shore_east"
			elif w: t = "shore_west"
			elif water.call(x + 1, y - 1): t = "shore_corner_ne"
			elif water.call(x - 1, y - 1): t = "shore_corner_nw"
			elif water.call(x + 1, y + 1): t = "shore_corner_se"
			elif water.call(x - 1, y + 1): t = "shore_corner_sw"
			if t != "":
				updates[Vector2i(x, y)] = t
	for c in updates:
		a.gset(c.x, c.y, updates[c])

static func _cc(a: GameArea, c: Vector2i) -> Vector2:
	return a.cell_center(c.x, c.y)

static func _landmarks(a: GameArea, rng: RandomNumberGenerator) -> void:
	# spawn points
	a.spawns["start"] = _cc(a, START + Vector2i(0, -1))
	a.spawns["cave"] = _cc(a, CAVE + Vector2i(0, 1))
	a.spawns["temple"] = _cc(a, TEMPLE + Vector2i(0, 2))
	# --- start beach: the wreck
	a.add_prop("rowboat", _cc(a, START + Vector2i(-5, 2)), 6.0, 2.0)  # your wrecked boat
	if a.has_meta("pier_head"):
		var ph: Vector2i = a.get_meta("pier_head")
		a.add_prop("canoe", _cc(a, ph + Vector2i(-3, -1)), 0.0, 1.5)
		a.add_prop("barrel", _cc(a, ph + Vector2i(2, 0)), 5.0)
		a.add_prop("life_ring", _cc(a, ph + Vector2i(-1, 0)))
		a.add_torch(_cc(a, ph + Vector2i(1, 0)))
	a.add_prop("crate", _cc(a, START + Vector2i(-6, 0)), 6.0)
	a.add_prop("barrel", _cc(a, START + Vector2i(-6, 1)), 5.0)
	a.add_prop("crate", _cc(a, START + Vector2i(-2, 3)), 6.0)
	a.add_prop("life_ring", _cc(a, START + Vector2i(1, 3)))
	a.add_prop("anchor", _cc(a, START + Vector2i(-7, 3)), 4.0)
	a.add_prop("beach_umbrella_red", _cc(a, START + Vector2i(6, -2)), 4.0, 1.5)
	a.add_prop("beach_chair", _cc(a, START + Vector2i(6, -1)))
	a.add_prop("beach_towel_blue", _cc(a, START + Vector2i(7, -1)))
	a.add_prop("sandcastle", _cc(a, START + Vector2i(5, 1)), 3.0)
	a.add_prop("beach_ball", _cc(a, START + Vector2i(7, 1)), 3.0)
	a.add_campfire(_cc(a, START + Vector2i(2, -2)))
	a.add_npc("fisherman", _cc(a, START + Vector2i(-1, -3)), "banda").make_soul(Color(1.0, 0.85, 0.5), 30.0)
	a.add_npc("parrot", _cc(a, START + Vector2i(4, -3)), "parrot").make_soul(Color(0.6, 1.0, 0.7), 34.0)
	a.add_interactable("sign", _cc(a, START + Vector2i(1, -6)), "", {"lines": ["NORTH: Village (?)", "Someone scratched underneath: \"DON'T GO AT NIGHT\""]})
	a.add_interactable("note", _cc(a, START + Vector2i(-5, 4)), "", {"note": "n1"})
	# --- village
	for o in [Vector2i(-4, -4), Vector2i(4, -4), Vector2i(-4, 4), Vector2i(4, 4)]:
		a.add_torch(_cc(a, VILLAGE + o))
	a.add_campfire(_cc(a, VILLAGE))
	var elder := a.add_npc("tribal_dancer", _cc(a, VILLAGE + Vector2i(0, -2)), "elder")
	elder.make_soul(Color(0.65, 0.8, 1.0), 22.0)
	elder.walk_speed = 7.0
	# wandering villager spirits, still walking their old routes
	for sp in [[Vector2i(-6, -3), "spirit_a"], [Vector2i(6, 4), "spirit_b"], [Vector2i(-3, 6), "spirit_c"]]:
		var v := a.add_npc(["tribal_dancer", "fisherman", "islander_explorer"][["spirit_a", "spirit_b", "spirit_c"].find(sp[1])], _cc(a, VILLAGE + sp[0]), sp[1])
		v.make_soul(Color(0.55, 0.9, 1.0), 52.0)
	a.add_interactable("sign", _cc(a, VILLAGE + Vector2i(2, 9)), "", {"lines": ["WELCOME TO SERAVELI", "The letters have been scratched so many times the wood is almost through."]})
	a.add_interactable("note", _cc(a, VILLAGE + Vector2i(-7, 1)), "", {"note": "n2"})
	for p in [Vector2i(-11, -2), Vector2i(-11, -1), Vector2i(10, 7), Vector2i(11, 7), Vector2i(-6, 7)]:
		a.add_prop(["crate", "barrel"][rng.randi() % 2], _cc(a, VILLAGE + p), 5.0)
	for x in range(-12, -6):
		a.add_prop("fence_h", _cc(a, VILLAGE + Vector2i(x, 8)), 0.0)
		a.block_cell(VILLAGE.x + x, VILLAGE.y + 8)
	a.add_prop("hammock", _cc(a, VILLAGE + Vector2i(9, -2)), 4.0)
	a.add_interactable("chest", _cc(a, VILLAGE + Vector2i(8, 7)), "ow:chest_village", {"loot": {"item": "coconut_drink", "n": 2}})
	# --- lagoon
	a.add_npc("mermaid", _cc(a, LAGOON + Vector2i(0, 6)), "mermaid").make_soul(Color(0.4, 1.0, 0.9), 20.0)
	a.add_interactable("note", _cc(a, LAGOON + Vector2i(-7, 2)), "", {"note": "n3"})
	a.add_prop("canoe", _cc(a, LAGOON + Vector2i(4, 6)), 5.0, 1.5)
	# --- cave
	a.add_interactable("portal", _cc(a, CAVE + Vector2i(0, -1)) + Vector2(-8, 4), "", {"to": "tide_caverns", "spawn": "entrance"})
	a.add_torch(_cc(a, CAVE + Vector2i(-3, 0)))
	a.add_torch(_cc(a, CAVE + Vector2i(2, 0)))
	a.add_interactable("sign", _cc(a, CAVE + Vector2i(4, 2)), "", {"lines": ["TIDE CAVERNS", "Under it, in a shaky hand: \"the crab got bigger\""]})
	a.add_interactable("note", _cc(a, CAVE + Vector2i(8, 6)), "", {"note": "n4"})
	a.add_campfire(_cc(a, CAVE + Vector2i(-5, 4)))
	# --- lighthouse
	var top := a.add_prop("lighthouse_top", _cc(a, TEMPLE + Vector2i(0, -4)) + Vector2(0, 8), 0.0, 3.0)
	top.z_index = 5
	var lit := Game.flag("ending_seen")
	var beam := a.add_light(top, Color(1.0, 0.85, 0.45) if lit else Color(0.6, 0.3, 1.0), 3.0 if lit else 1.8, 1.2 if lit else 0.7)
	beam.position = Vector2(0, -24)
	a.add_interactable("portal", _cc(a, TEMPLE), "", {"to": "void_temple", "spawn": "entrance", "req_shards": 2,
		"locked_lines": ["The lighthouse door is sealed by two dim hollows shaped like shards.", "It needs two shards of the Great Lamp to open."]})
	a.add_torch(_cc(a, TEMPLE + Vector2i(-2, 2)))
	a.add_torch(_cc(a, TEMPLE + Vector2i(2, 2)))
	a.add_campfire(_cc(a, TEMPLE + Vector2i(5, 5)))
	if not Game.flag("ending_seen"):   # the echo was your own lost shadow; it is gone once the lamp burns
		var echo := a.add_npc("hero", _cc(a, TEMPLE + Vector2i(-6, 5)), "echo")
		echo.sprite.material = FX.make_actor_material(true, Color(0.2, 0.15, 0.35), true)
		echo.wander_r = 14.0
		echo.walk_speed = 6.0
	# --- grove arena: tyrant boss
	for i in 10:
		var ang := TAU * i / 10.0
		var c := GROVE + Vector2i(roundi(cos(ang) * 9.5), roundi(sin(ang) * 8.5))
		if i != 2:  # leave the south-east gap where the path enters
			a.add_prop("rock_mossy", _cc(a, c), 7.0, 1.5)
	if not Game.is_opened("boss:ape_alpha"):
		var arena := Rect2(_cc(a, GROVE) - Vector2(140, 120), Vector2(280, 240))
		var boss := a.add_boss("ape_alpha", _cc(a, GROVE), arena)
		a.triggers.append({"rect": Rect2(_cc(a, GROVE) - Vector2(90, 80), Vector2(180, 160)), "done": false, "fn": func():
			if Game.main:
				Game.main.start_boss(boss)
		})
		boss.boss_died.connect(func():
			if Game.main:
				Game.main.end_boss()
			_shard_chest(a, _cc(a, GROVE), "grove_shard")
		)
	else:
		_shard_chest(a, _cc(a, GROVE), "grove_shard")
	# --- dig spots (secrets)
	var digs := [
		[Vector2i(16, 80), {"item": "pearl"}], [Vector2i(112, 76), {"coins": 30}], [Vector2i(46, 10), {"item": "pineapple"}],
		[Vector2i(118, 30), {"item": "pearl"}], [Vector2i(80, 88), {"item": "coconut_drink", "n": 2}], [Vector2i(10, 44), {"coins": 25, "item": "mango", "n": 2}],
	]
	for dg in digs:
		var c := a.free_cell_near(dg[0], 8)
		a.add_interactable("dig", _cc(a, c), "ow:dig:%d:%d" % [dg[0].x, dg[0].y], {"loot": dg[1]})
	# --- hidden chests in far corners
	var chests := [[Vector2i(8, 12), {"item": "pineapple"}], [Vector2i(120, 10), {"item": "pearl"}], [Vector2i(6, 58), {"item": "mango", "n": 3}], [Vector2i(122, 86), {"coins": 40}]]
	for ch in chests:
		var c := a.free_cell_near(ch[0], 10)
		a.add_interactable("chest", _cc(a, c), "ow:chest:%d:%d" % [ch[0].x, ch[0].y], {"loot": ch[1]})

## After the ending every shadow is a person again: islanders, fishers, dancers and the
## corsairs who stole the shards. None of them remember where they have been.
const HUMAN_SPRITES := ["fisherman", "tribal_dancer", "islander_explorer", "pirate", "fisherman", "tribal_dancer"]

static func _populate_humans(a: GameArea, rng: RandomNumberGenerator, nodeco: Dictionary) -> void:
	var count := 0
	var tries := 0
	while count < 30 and tries < 4000:
		tries += 1
		var x := rng.randi_range(3, W - 4); var y := rng.randi_range(3, H - 4)
		if a.is_solid_cell(x, y) or not a.is_reachable(x, y) or nodeco.has(Vector2i(x, y)):
			continue
		var spr: String = HUMAN_SPRITES[count % HUMAN_SPRITES.size()]
		var h := a.add_npc(spr, a.cell_center(x, y), "human_%d" % count)
		h.wander_r = 90.0
		h.walk_speed = rng.randf_range(12.0, 20.0)
		count += 1
	# a few gathered back home in the village, and on the harbour beach
	for i in 6:
		var c := a.free_cell_near(VILLAGE + Vector2i(rng.randi_range(-8, 8), rng.randi_range(-6, 6)), 4)
		var h2 := a.add_npc(HUMAN_SPRITES[i % HUMAN_SPRITES.size()], a.cell_center(c.x, c.y), "human_v%d" % i)
		h2.wander_r = 50.0
		h2.walk_speed = 12.0
	for i in 4:
		var c2 := a.free_cell_near(START + Vector2i(rng.randi_range(-10, 10), rng.randi_range(-4, 2)), 4)
		var h3 := a.add_npc(HUMAN_SPRITES[(i + 2) % HUMAN_SPRITES.size()], a.cell_center(c2.x, c2.y), "human_s%d" % i)
		h3.wander_r = 60.0
		h3.walk_speed = 14.0
	# ordinary crabs scuttle on the beaches again
	for i in 10:
		var c3 := a.free_cell_near(Vector2i(rng.randi_range(20, 108), rng.randi_range(70, 90)), 6)
		if a.gget(c3.x, c3.y).begins_with("sand") or a.gget(c3.x, c3.y).begins_with("shore"):
			a.add_ambient("crab_ambient", a.cell_center(c3.x, c3.y))

static func _shard_chest(a: GameArea, pos: Vector2, shard: String) -> void:
	var uid := "chest:" + shard
	var c := a.add_interactable("chest", pos, uid, {"loot": {"key_item": shard}})
	if not Game.is_opened(uid):
		FX.ring(a.fx, pos, 40.0, Color(1, 1, 0.6), 0.6)
		var l := a.add_light(c, Color(1, 0.9, 0.5), 1.2, 1.0)
		l.position = Vector2(0, -8)

static func _decorate(a: GameArea, rng: RandomNumberGenerator, nodeco: Dictionary) -> void:
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			var c := Vector2i(x, y)
			if nodeco.has(c) or a.is_solid_cell(x, y) or a.oget(x, y) != "":
				continue
			var g := a.gget(x, y)
			var p := a.cell_center(x, y) + Vector2(rng.randf_range(-4, 4), rng.randf_range(-3, 3))
			var r := rng.randf()
			if g.begins_with("sand") and not g.begins_with("sand_wet"):
				if r < 0.022:
					a.add_prop(["palm_tree_top_1", "palm_tree_top_2"][rng.randi() % 2], p, 4.0, 2.0)
					a.block_cell(x, y)
				elif r < 0.05:
					a.add_prop(["seashell_pink", "seashell_scallop", "seashell_spiral", "starfish"][rng.randi() % 4], p, 0.0, 0.75, 6)
				elif r < 0.056:
					a.add_prop("rock_small", p, 4.0)
			elif g.begins_with("shore"):
				if r < 0.03:
					a.add_prop(["seashell_pink", "starfish"][rng.randi() % 2], p, 0.0, 0.75, 6)
			elif g.begins_with("grass") or g == "dirt":
				if r < 0.03:
					a.add_prop(["bush_green", "bush_berry"][rng.randi() % 2], p, 5.0)
					a.block_cell(x, y)
				elif r < 0.075:
					a.add_prop(["flowers_pink", "flowers_red", "hibiscus"][rng.randi() % 3], p, 0.0, 1.0, 4)
				elif r < 0.082:
					a.add_prop("rock_big", p, 6.0)
					a.block_cell(x, y)
				elif r < 0.09:
					a.add_prop("palm_tree_top_2", p, 4.0, 2.0)
					a.block_cell(x, y)
				elif r < 0.096:
					a.add_prop("palm_tree_side", p, 3.0, 1.5)
					a.block_cell(x, y)
			elif g == "jungle_floor":
				if r < 0.07:
					a.add_prop(["palm_tree_top_1", "palm_tree_top_2"][rng.randi() % 2], p, 4.0, 2.0)
					a.block_cell(x, y)
				elif r < 0.16:
					a.add_prop("fern", p, 0.0, 1.0, 3)
				elif r < 0.2:
					a.add_prop("bush_green", p, 5.0)
					a.block_cell(x, y)
				elif r < 0.21:
					a.add_prop("rock_mossy", p, 5.0)
					a.block_cell(x, y)
			elif g == "volcanic_sand" or g == "rock_floor":
				if r < 0.03:
					a.add_prop("rock_big", p, 6.0)
					a.block_cell(x, y)
				elif r < 0.07:
					a.add_prop("rock_small", p, 0.0, 1.0, 4)

static func _populate(a: GameArea, rng: RandomNumberGenerator, nodeco: Dictionary) -> void:
	# ambient life
	for i in 9:
		a.add_ambient("seagull", a.cell_center(rng.randi_range(20, 108), rng.randi_range(60, 92)))
	var fish_n := 0
	var tries := 0
	while fish_n < 18 and tries < 2000:
		tries += 1
		var x := rng.randi_range(0, W - 1); var y := rng.randi_range(0, H - 1)
		var g := a.gget(x, y)
		if g == "water_shallow" or g == "water_lagoon":
			a.add_ambient(["fish_blue", "fish_orange"][rng.randi() % 2], a.cell_center(x, y))
			fish_n += 1
	for i in 4:
		var c := a.free_cell_near(Vector2i(rng.randi_range(40, 90), rng.randi_range(80, 90)), 6)
		if a.gget(c.x, c.y).begins_with("sand") or a.gget(c.x, c.y).begins_with("shore"):
			a.add_ambient("turtle", a.cell_center(c.x, c.y))
	for i in 24:
		var c := Vector2i(rng.randi_range(4, 50), rng.randi_range(4, 46))
		if a.gget(c.x, c.y) == "jungle_floor":
			a.add_ambient("firefly", a.cell_center(c.x, c.y))
	for i in 4:
		var c := a.free_cell_near(Vector2i(rng.randi_range(10, 46), rng.randi_range(8, 44)), 5)
		a.add_ambient("parrot", a.cell_center(c.x, c.y))
	if Game.flag("ending_seen"):
		_populate_humans(a, rng, nodeco)
		return
	# shadow creatures
	var count := 0
	tries = 0
	while count < 64 and tries < 5000:
		tries += 1
		var x := rng.randi_range(3, W - 4); var y := rng.randi_range(3, H - 4)
		var c := Vector2i(x, y)
		if a.is_solid_cell(x, y) or nodeco.has(c) or not a.is_reachable(x, y):
			continue
		if Vector2(c - START).length() < 16 or Vector2(c - VILLAGE).length() < 14 or Vector2(c - GROVE).length() < 12 or Vector2(c - TEMPLE).length() < 9:
			continue
		var g := a.gget(x, y)
		var t := ""
		var dist := Vector2(c - START).length()
		if g.begins_with("sand") or g.begins_with("shore"):
			t = ["shadow_crab", "shadow_crab", "shadow_gull", "shadow_jelly"][rng.randi() % 4]
		elif g == "jungle_floor":
			t = ["shadow_monkey", "shadow_monkey", "shadow_gull", "shadow_dancer"][rng.randi() % 4]
		elif g == "volcanic_sand" or g == "rock_floor":
			t = ["shadow_pirate", "shadow_dancer", "shadow_gull", "shadow_pirate"][rng.randi() % 4]
		elif g.begins_with("grass") or g == "dirt" or g == "dirt_path":
			t = ["shadow_crab", "shadow_gull", "shadow_monkey" if dist > 30 else "shadow_crab", "shadow_pirate" if dist > 45 else "shadow_jelly"][rng.randi() % 4]
		if t == "":
			continue
		var pack := rng.randi_range(1, 3 if t != "shadow_pirate" else 2)
		for k in pack:
			var p := a.cell_center(x, y) + Vector2(rng.randf_range(-20, 20), rng.randf_range(-20, 20))
			if a.is_solid_px(p):
				continue
			var e := a.add_enemy(t, p)
			e.level_bonus = int(dist / 30.0)
			count += 1
