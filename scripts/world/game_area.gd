class_name GameArea
extends Node2D
## A playable map: ground + overlay tilemaps, y-sorted entities, fog of war, minimap.

static var bank: TileBank

var area_id := ""
var display_name := ""
var W := 0
var H := 0
var ground_names: Array = []
var over_names: Array = []
var solid := PackedByteArray()
var explored := PackedByteArray()

var ground: TileMapLayer
var over: TileMapLayer
var entities: Node2D
var fx: Node2D
var fog: Sprite2D
var fog_img: Image
var fog_tex: ImageTexture
var mini_img: Image
var mini_tex: ImageTexture
var camera: Camera2D
var modulate_node: CanvasModulate
var player: PlayerChar

var dark := false
var night := false
var player_light: PointLight2D
var ambient := Color(1, 1, 1)
var reveal_radius := 7
var music := "overworld"
var regions: Array = []        # [{rect:Rect2i, name:String, music:String}]
var landmarks: Array = []      # [{cell:Vector2i, name:String}] shown on map when explored
var spawns := {}               # name -> Vector2
var rng := RandomNumberGenerator.new()
var boss_active: Node = null
var triggers: Array = []      # [{rect:Rect2, fn:Callable, done:bool}]
var gates: Array = []         # StaticBody2D nodes closed during boss fights
const WALKABLE_OVER := ["boardwalk_h", "boardwalk_v", "bridge_rope_h", "dock_h", "dock_v", "@cave_mouth"]
var _fog_dirty := false
var _last_cell := Vector2i(-999, -999)
var current_region := ""

func setup(id: String, w: int, h: int) -> void:
	if bank == null:
		bank = TileBank.new()
	area_id = id
	W = w; H = h
	ground_names.resize(W * H); ground_names.fill("@void")
	over_names.resize(W * H); over_names.fill("")
	solid.resize(W * H); solid.fill(0)
	explored.resize(W * H); explored.fill(0)
	ground = TileMapLayer.new(); ground.tile_set = bank.tileset; ground.z_index = -20; ground.name = "Ground"
	add_child(ground)
	over = TileMapLayer.new(); over.tile_set = bank.tileset; over.z_index = -19; over.name = "Over"
	add_child(over)
	entities = Node2D.new(); entities.y_sort_enabled = true; entities.name = "Entities"
	add_child(entities)
	fx = Node2D.new(); fx.z_index = 50; fx.name = "FX"
	add_child(fx)

# ------------------------------------------------------------------ grid
func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H

func gget(x: int, y: int) -> String:
	if not inb(x, y):
		return "@void"
	return ground_names[y * W + x]

func gset(x: int, y: int, name: String) -> void:
	if inb(x, y):
		ground_names[y * W + x] = name

func oget(x: int, y: int) -> String:
	if not inb(x, y):
		return ""
	return over_names[y * W + x]

func oset(x: int, y: int, name: String) -> void:
	if inb(x, y):
		over_names[y * W + x] = name

func is_solid_cell(x: int, y: int) -> bool:
	if not inb(x, y):
		return true
	return solid[y * W + x] != 0

func is_solid_px(p: Vector2) -> bool:
	return is_solid_cell(int(floor(p.x / 16.0)), int(floor(p.y / 16.0)))

func block_cell(x: int, y: int) -> void:
	if inb(x, y):
		solid[y * W + x] = 1

func cell_center(x: int, y: int) -> Vector2:
	return Vector2(x * 16 + 8, y * 16 + 8)

func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / 16.0)), int(floor(p.y / 16.0)))

func is_water(name: String) -> bool:
	return name.begins_with("water")

func finalize() -> void:
	for y in H:
		for x in W:
			var g: String = ground_names[y * W + x]
			ground.set_cell(Vector2i(x, y), 0, bank.id(g))
			var o: String = over_names[y * W + x]
			if o != "":
				over.set_cell(Vector2i(x, y), 0, bank.id(o))
			var s := bank.is_solid_name(g) or (o != "" and bank.is_solid_name(o))
			if o in WALKABLE_OVER:
				s = false
				if bank.is_solid_name(g):
					# a bridge over water: use the collision-free alternative of the ground tile
					ground.set_cell(Vector2i(x, y), 0, bank.id(g), 1)
			if s:
				solid[y * W + x] = 1
	# fog of war
	var saved: String = Game.data["explored"].get(area_id, "")
	if saved != "":
		var raw := Marshalls.base64_to_raw(saved)
		if raw.size() == explored.size():
			explored = raw
	fog_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	mini_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	mini_img.fill(Color(0, 0, 0, 0))
	for y in H:
		for x in W:
			var e := explored[y * W + x] != 0
			fog_img.set_pixel(x, y, Color(0.03, 0.03, 0.08, 0.0 if e else 1.0))
			if e:
				mini_img.set_pixel(x, y, _mini_color(x, y))
	fog_tex = ImageTexture.create_from_image(fog_img)
	mini_tex = ImageTexture.create_from_image(mini_img)
	fog = Sprite2D.new()
	fog.texture = fog_tex
	fog.centered = false
	fog.scale = Vector2(16, 16)
	fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	fog.z_index = 90
	fog.material = _fog_material()
	add_child(fog)
	# lighting
	modulate_node = CanvasModulate.new()
	modulate_node.color = ambient
	add_child(modulate_node)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	camera.limit_left = 0; camera.limit_top = 0
	camera.limit_right = W * 16; camera.limit_bottom = H * 16
	add_child(camera)

func _mini_color(x: int, y: int) -> Color:
	var o: String = over_names[y * W + x]
	if o != "":
		return bank.colors.get(o, Color.WHITE)
	return bank.colors.get(ground_names[y * W + x], Color.BLACK)

func _fog_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
float h(vec2 p){ return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float n(vec2 p){ vec2 i=floor(p); vec2 f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(h(i),h(i+vec2(1,0)),f.x), mix(h(i+vec2(0,1)),h(i+vec2(1,1)),f.x), f.y); }
void fragment(){
 vec4 c = texture(TEXTURE, UV);
 vec2 p = UV * vec2(textureSize(TEXTURE,0)) * 0.35;
 float m = n(p + vec2(TIME*0.15, TIME*0.05)) * 0.6 + n(p*2.3 - vec2(TIME*0.1, 0.0)) * 0.4;
 float a = smoothstep(0.05, 0.95, c.a);
 vec3 col = mix(vec3(0.02,0.02,0.06), vec3(0.10,0.08,0.18), m);
 COLOR = vec4(col, a * (0.9 + 0.1*m));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	return mat

func reveal(c: Vector2i, r: int) -> void:
	var changed := false
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if not inb(x, y):
				continue
			if Vector2(x - c.x, y - c.y).length() > r + 0.3:
				continue
			var i := y * W + x
			if explored[i] == 0:
				explored[i] = 1
				fog_img.set_pixel(x, y, Color(0.03, 0.03, 0.08, 0.0))
				mini_img.set_pixel(x, y, _mini_color(x, y))
				changed = true
	if changed:
		_fog_dirty = true

func reveal_all() -> void:
	explored.fill(1)
	for y in H:
		for x in W:
			fog_img.set_pixel(x, y, Color(0, 0, 0, 0))
			mini_img.set_pixel(x, y, _mini_color(x, y))
	_fog_dirty = true

func explored_ratio() -> float:
	var n := 0
	var tot := 0
	for i in explored.size():
		if solid[i] == 0 or ground_names[i].begins_with("water_shallow"):
			tot += 1
			if explored[i] != 0:
				n += 1
	return float(n) / max(1, tot)

func save_state() -> void:
	Game.data["explored"][area_id] = Marshalls.raw_to_base64(explored)

func _process(_d: float) -> void:
	if player and is_instance_valid(player):
		var c := cell_of(player.global_position)
		if c != _last_cell:
			_last_cell = c
			reveal(c, reveal_radius)
			_check_region(c)
		camera.global_position = player.global_position + player.cam_lead
		if player_light:
			player_light.texture_scale = lerpf(player_light.texture_scale, _lantern_scale(), 0.05)
		for tr in triggers:
			if tr["done"]:
				continue
			if (tr["rect"] as Rect2).has_point(player.global_position):
				tr["done"] = true
				(tr["fn"] as Callable).call()
	if _fog_dirty:
		_fog_dirty = false
		fog_tex.update(fog_img)
		mini_tex.update(mini_img)

func _check_region(c: Vector2i) -> void:
	var name := display_name
	var mus := music
	for r in regions:
		if (r["rect"] as Rect2i).has_point(c):
			name = r["name"]
			mus = r.get("music", music)
			break
	if name != current_region:
		current_region = name
		if Game.main:
			Game.main.show_banner(name)
		if boss_active == null:
			Sfx.play_music(mus)

# ------------------------------------------------------------------ props & spawning
func add_prop(tex_name: String, pos: Vector2, radius := 0.0, scl := 1.0, extra_y := 0.0) -> Node2D:
	var root: Node2D
	if radius > 0.0:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var cs := CollisionShape2D.new()
		var sh := CircleShape2D.new(); sh.radius = radius
		cs.shape = sh
		body.add_child(cs)
		root = body
	else:
		root = Node2D.new()
	root.position = pos
	var s := Sprite2D.new()
	s.texture = Game.tex(tex_name)
	s.scale = Vector2(scl, scl)
	s.offset = Vector2(0, -8 + extra_y)
	s.name = "Sprite"
	root.add_child(s)
	entities.add_child(root)
	return root

func add_light(parent: Node2D, color: Color, scale_v := 1.0, energy := 1.0, flicker := true) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = FX.light_texture()
	l.color = color
	l.texture_scale = scale_v
	l.energy = energy
	l.shadow_enabled = false
	parent.add_child(l)
	if flicker:
		var f := Flicker.new()
		f.light = l
		f.base = energy
		l.add_child(f)
	return l

func add_torch(pos: Vector2) -> Node2D:
	var t := add_prop("tiki_torch", pos, 3.0)
	var lt := add_light(t, Color(1.0, 0.65, 0.3), 1.3, 1.1)
	lt.position = Vector2(0, -12)
	var p := FX.fire_particles()
	p.position = Vector2(0, -14)
	t.add_child(p)
	return t

func add_campfire(pos: Vector2, checkpoint := true) -> Node2D:
	var c := Interactable.new()
	c.kind = "campfire"
	c.position = pos
	c.uid = "%s:fire:%d:%d" % [area_id, int(pos.x), int(pos.y)]
	entities.add_child(c)
	c.setup_sprite("campfire_1", "campfire_2")
	c.add_blocker(5)
	var lt := add_light(c, Color(1.0, 0.6, 0.25), 2.4, 1.2)
	lt.position = Vector2(0, -6)
	var p := FX.fire_particles()
	p.position = Vector2(0, -8)
	c.add_child(p)
	c.prompt = "Rest" if checkpoint else ""
	return c

func add_enemy(type: String, pos: Vector2) -> EnemyChar:
	var e := EnemyChar.new()
	e.type = type
	e.position = pos
	e.area = self
	entities.add_child(e)
	return e

func add_boss(type: String, pos: Vector2, arena: Rect2) -> BossChar:
	var b := BossChar.new()
	b.type = type
	b.position = pos
	b.area = self
	b.arena = arena
	entities.add_child(b)
	return b

func add_interactable(kind: String, pos: Vector2, uid := "", info := {}) -> Interactable:
	var it := Interactable.new()
	it.kind = kind
	it.position = pos
	it.uid = uid
	it.info = info
	entities.add_child(it)
	return it

func add_npc(tex_name: String, pos: Vector2, npc_id: String) -> Interactable:
	var it := add_interactable("npc", pos, npc_id)
	it.npc_id = npc_id
	it.setup_sprite(tex_name)
	it.add_blocker(5)
	it.prompt = "Talk"
	return it

func add_ambient(type: String, pos: Vector2) -> Node2D:
	var a := Critter.new()
	a.type = type
	a.position = pos
	a.area = self
	entities.add_child(a)
	return a

var reachable := PackedByteArray()

## Flood-fill from a start cell over walkable ground, so treasure and enemies are only
## ever placed where the player can actually walk.
func compute_reachable(from: Vector2i) -> void:
	reachable.resize(W * H)
	reachable.fill(0)
	var stack: Array[Vector2i] = [from]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if not inb(c.x, c.y):
			continue
		var i := c.y * W + c.x
		if reachable[i] != 0:
			continue
		if solid[i] != 0 and not (over_names[i] in WALKABLE_OVER):
			continue
		reachable[i] = 1
		stack.append(c + Vector2i(1, 0)); stack.append(c + Vector2i(-1, 0))
		stack.append(c + Vector2i(0, 1)); stack.append(c + Vector2i(0, -1))

func is_reachable(x: int, y: int) -> bool:
	if reachable.is_empty():
		return not is_solid_cell(x, y)
	return inb(x, y) and reachable[y * W + x] != 0

func free_cell_near(c: Vector2i, max_r := 6) -> Vector2i:
	for r in max_r * 3:
		for y in range(c.y - r, c.y + r + 1):
			for x in range(c.x - r, c.x + r + 1):
				if not is_solid_cell(x, y) and is_reachable(x, y):
					return Vector2i(x, y)
	return c

func spawn_player(pos: Vector2) -> PlayerChar:
	player = PlayerChar.new()
	player.area = self
	player.position = pos
	entities.add_child(player)
	camera.global_position = pos
	camera.reset_smoothing()
	if dark or night:
		player_light = add_light(player, Color(1.0, 0.86, 0.6), _lantern_scale(), 1.05, true)
		player_light.position = Vector2(0, -6)
	reveal(cell_of(pos), reveal_radius)
	return player

func _lantern_scale() -> float:
	if Game.has_key_item("lantern"):
		return 2.3 if night else 2.6
	return 1.4 if night else 1.5

func on_player_died() -> void:
	pass
