class_name TileBank
extends RefCounted
## Builds a single runtime atlas + TileSet from the individual 16x16 sprites.
## Each tile reserves two atlas cells so it can carry a 2-frame animation.

const TILES := [
	# name, frame2 (or ""), solid, minimap color
	["sand_1", "", false, "e8d8a0"], ["sand_2", "", false, "e8d8a0"], ["sand_3", "", false, "e0d098"],
	["sand_shells", "", false, "e8d8a0"], ["sand_wet", "", false, "c8b880"],
	["grass_1", "", false, "60b048"], ["grass_2", "", false, "58a840"], ["grass_3", "", false, "60b048"],
	["grass_flowers", "", false, "70b850"], ["jungle_floor", "", false, "2f6e30"],
	["dirt", "", false, "a07850"], ["dirt_path", "", false, "b89060"],
	["rock_floor", "", false, "707078"], ["wet_stone_floor", "", false, "6888a0"], ["volcanic_sand", "", false, "404048"],
	["water_deep", "water_deep_2", true, "2858a8"], ["water_shallow", "water_shallow_2", true, "58b8e0"],
	["water_lagoon", "water_shallow_2", true, "40c8b8"], ["water_tide_pool", "water_shallow", true, "5098c8"],
	["shore_north", "", false, "d8d0a0"], ["shore_south", "", false, "d8d0a0"], ["shore_east", "", false, "d8d0a0"], ["shore_west", "", false, "d8d0a0"],
	["shore_corner_ne", "", false, "e0d8a0"], ["shore_corner_nw", "", false, "e0d8a0"], ["shore_corner_se", "", false, "e0d8a0"], ["shore_corner_sw", "", false, "e0d8a0"],
	["shore_inner_ne", "", false, "d0c898"], ["shore_inner_nw", "", false, "d0c898"], ["shore_inner_se", "", false, "d0c898"], ["shore_inner_sw", "", false, "d0c898"],
	["stone_wall", "", true, "9898a0"], ["cliff_face", "", true, "706050"], ["cliff_face_sand", "", true, "908060"],
	["hut_wall_wood", "", true, "a07040"], ["hut_roof_thatch", "", true, "d8b048"], ["hut_roof_top", "", true, "e0c050"],
	["hut_door", "", true, "805030"], ["hut_window", "", true, "805030"],
	["boardwalk_h", "", false, "a87848"], ["boardwalk_v", "", false, "a87848"], ["bridge_rope_h", "", false, "a87848"],
	["dock_h", "", false, "a87848"], ["dock_v", "", false, "a87848"],
	["@void", "", true, "101018"], ["@wall_top", "", true, "38384a"], ["@cave_mouth", "", false, "000000"],
	["@temple_floor", "", false, "503850"], ["@rune_floor", "@rune_floor2", false, "805080"],
	["@cave_exit", "", false, "6080b0"], ["@stairs_up", "", false, "8a7a90"],
]

var tileset: TileSet
var coords := {}       # name -> Vector2i
var solid := {}        # name -> bool
var colors := {}       # name -> Color
var names_by_coord := {}

func _init() -> void:
	var n := TILES.size()
	var atlas := Image.create(n * 32, 16, false, Image.FORMAT_RGBA8)
	for i in n:
		var t: Array = TILES[i]
		var a: Image = _img_for(t[0])
		atlas.blit_rect(a, Rect2i(0, 0, 16, 16), Vector2i(i * 32, 0))
		var b: Image = _img_for(t[1]) if t[1] != "" else a
		atlas.blit_rect(b, Rect2i(0, 0, 16, 16), Vector2i(i * 32 + 16, 0))
	var tex := ImageTexture.create_from_image(atlas)
	tileset = TileSet.new()
	tileset.tile_size = Vector2i(16, 16)
	tileset.add_physics_layer()
	tileset.set_physics_layer_collision_layer(0, 1)
	tileset.set_physics_layer_collision_mask(0, 0)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	tileset.add_source(src, 0)
	var sq := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	for i in n:
		var t: Array = TILES[i]
		var c := Vector2i(i * 2, 0)
		src.create_tile(c)
		if t[1] != "":
			src.set_tile_animation_columns(c, 0)
			src.set_tile_animation_frames_count(c, 2)
			src.set_tile_animation_frame_duration(c, 0, 0.75 + (i % 3) * 0.15)
			src.set_tile_animation_frame_duration(c, 1, 0.75 + (i % 3) * 0.15)
		if t[2]:
			var td: TileData = src.get_tile_data(c, 0)
			td.add_collision_polygon(0)
			td.set_collision_polygon_points(0, 0, sq)
			src.create_alternative_tile(c, 1)  # collision-free variant (bridges over water)
		coords[t[0]] = c
		solid[t[0]] = t[2]
		colors[t[0]] = Color(t[3])
		names_by_coord[c] = t[0]

func _img_for(name: String) -> Image:
	if name.begins_with("@"):
		return _procedural(name)
	return Game.img(name)

func _procedural(name: String) -> Image:
	var im := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	match name:
		"@void":
			im.fill(Color("0b0a12"))
			for i in 6:
				im.set_pixel(rng.randi_range(0, 15), rng.randi_range(0, 15), Color("15131f"))
		"@wall_top":
			im.fill(Color("2a2838"))
			for y in 16:
				for x in 16:
					if (y % 8 == 0) or ((x + (8 if (y / 8) % 2 == 1 else 0)) % 16 == 0):
						im.set_pixel(x, y, Color("1c1a28"))
					elif rng.randf() < 0.08:
						im.set_pixel(x, y, Color("34324a"))
		"@cave_mouth":
			for y in 16:
				for x in 16:
					var d := float(y) / 16.0
					im.set_pixel(x, y, Color(0.02, 0.02, 0.05).lerp(Color(0.12, 0.08, 0.1), d * 0.4))
		"@temple_floor":
			im.fill(Color("3c2c3e"))
			for y in 16:
				for x in 16:
					if x % 8 == 0 or y % 8 == 0:
						im.set_pixel(x, y, Color("2c1f2e"))
					elif rng.randf() < 0.1:
						im.set_pixel(x, y, Color("4a3850"))
		"@cave_exit":
			# a ragged opening in the rock wall; night sky and moonlight beyond
			for y in 16:
				for x in 16:
					var edge := absf(x - 7.5) / 8.0
					var arch := 3.0 + edge * edge * 9.0 + rng.randf() * 1.2
					if y < arch:
						im.set_pixel(x, y, Color("4a4a56") if rng.randf() < 0.7 else Color("5a5a68"))
					else:
						var k := float(y) / 16.0
						var sky := Color(0.20, 0.28, 0.48).lerp(Color(0.05, 0.06, 0.12), k * 0.9)
						if rng.randf() < 0.04 and y < 9:
							sky = Color(0.9, 0.92, 1.0)
						im.set_pixel(x, y, sky)
			for x in 16:
				im.set_pixel(x, 15, Color("3a3a46"))
		"@stairs_up":
			# worn stone steps climbing toward a faint light
			for y in 16:
				for x in 16:
					var base := Color("3c2c3e").lerp(Color("a898b0"), 1.0 - float(y) / 16.0)
					if y % 4 == 0:
						base = base.darkened(0.45)
					if x == 0 or x == 15:
						base = Color("2a1f2e")
					im.set_pixel(x, y, base)
		"@rune_floor", "@rune_floor2":
			im.fill(Color("3c2c3e"))
			var glow := Color("c060ff") if name == "@rune_floor" else Color("8040c0")
			for i in 16:
				im.set_pixel(i, 7, glow); im.set_pixel(7, i, glow)
				im.set_pixel(i, i, glow.darkened(0.3)); im.set_pixel(15 - i, i, glow.darkened(0.3))
	return im

func id(name: String) -> Vector2i:
	return coords.get(name, coords["@void"])

func is_solid_name(name: String) -> bool:
	return bool(solid.get(name, false))
