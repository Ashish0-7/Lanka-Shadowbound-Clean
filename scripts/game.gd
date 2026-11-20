extends Node
## Global game state, databases, helpers, save/load.

signal stats_changed
signal inventory_changed
signal toast(text: String, color: Color)

const TILE := 16
const SAVE_PATH := "user://lanka_save.json"
const SPRITE_DIRS := ["beach", "characters", "critters", "ground", "items", "nature", "props", "shore", "water", "wood"]

var data: Dictionary = {}
var options := {"text_speed": 1, "volume": 0.8, "shake": true}
var main: Node = null  # set by main.gd
var _tex_cache := {}
var _tex_index := {}

# ---------------------------------------------------------------- databases
const ITEMS := {
	"banana": {"name": "Banana", "icon": "banana", "desc": "A sweet island banana. Restores 20 HP.", "hp": 20},
	"mango": {"name": "Ripe Mango", "icon": "mango", "desc": "Sunset-colored mango. Restores 40 HP.", "hp": 40},
	"coconut": {"name": "Coconut", "icon": "coconut", "desc": "Hard shell, cool milk. Restores 30 MP.", "mp": 30},
	"coconut_drink": {"name": "Coco Tonic", "icon": "coconut_drink", "desc": "A fizzy island tonic. Restores 70 HP and 40 MP.", "hp": 70, "mp": 40},
	"pineapple": {"name": "Gold Pineapple", "icon": "pineapple", "desc": "Legend says it holds sunlight. Fully restores HP and MP.", "hp": 9999, "mp": 9999},
	"pearl": {"name": "Moon Pearl", "icon": "pearl_oyster", "desc": "Hums softly. Use to raise max HP by 15 permanently.", "maxhp": 15},
}

const KEY_ITEMS := {
	"lantern": {"name": "Sun Lantern", "icon": "tiki_torch", "desc": "Banda's old lantern. Pushes back the dark in caves."},
	"shovel": {"name": "Shovel", "icon": "shovel", "desc": "Dig at red X marks to find what the island buried."},
	"key": {"name": "Rusted Key", "icon": "golden_key", "desc": "Opens one sealed door. It is warm to the touch."},
	"tide_shard": {"name": "Tide Shard", "icon": "pearl_oyster", "desc": "A shard of the Great Lamp. It smells of the sea.", "tint": Color(0.5, 0.85, 1.0)},
	"grove_shard": {"name": "Grove Shard", "icon": "pearl_oyster", "desc": "A shard of the Great Lamp. Warm like moss in sun.", "tint": Color(0.55, 1.0, 0.5)},
	"ember_shard": {"name": "Ember Shard", "icon": "pearl_oyster", "desc": "The heart of the Great Lamp. It burns without heat.", "tint": Color(1.0, 0.6, 0.3)},
	"rod": {"name": "Fishing Rod", "icon": "fishing_rod", "desc": "Banda's spare rod. The fish here have no shadows."},
}

const SKILLS := {
	"whirl": {"name": "Whirlwind", "key": "Q", "cost": 18, "cd": 3.0, "desc": "Spin your blade, striking everything nearby."},
	"bolt": {"name": "Sun Bolt", "key": "E", "cost": 10, "cd": 0.8, "desc": "Hurl a bolt of trapped sunlight."},
	"radiant": {"name": "Radiance", "key": "Tab", "cost": 40, "cd": 10.0, "desc": "A burst of lamp-light. Burns shadows and reveals the unknown around you."},
}

const CODEX := [
	{"id": "shadow_crab", "name": "Shade Crab", "desc": "Once a shore crab. The dark made it hungry. Charges in straight lines."},
	{"id": "shadow_gull", "name": "Hollow Gull", "desc": "It circles, then dives. It casts no reflection on water."},
	{"id": "shadow_jelly", "name": "Gloom Jelly", "desc": "Drifts and spits orbs of cold shadow. Keep moving."},
	{"id": "shadow_monkey", "name": "Dusk Monkey", "desc": "Leaps from great distance and slams down. Watch for the crouch."},
	{"id": "shadow_hermit", "name": "Shell Wraith", "desc": "Hides in a stolen shell. Very hard to hurt from the front."},
	{"id": "shadow_pirate", "name": "Drowned Corsair", "desc": "One of the crew who stole the shards. Still loyal. Still cursed."},
	{"id": "shadow_dancer", "name": "Ash Dancer", "desc": "Villagers who danced to keep the lamp lit. Now they dance for it to stay dark."},
	{"id": "tide_king", "name": "The Tide King", "desc": "A crab grown vast on stolen light. Guarded the Tide Shard in the caverns."},
	{"id": "ape_alpha", "name": "Grove Tyrant", "desc": "Alpha of the dusk troop. Wore the Grove Shard like a crown."},
	{"id": "nameless", "name": "THE NAMELESS", "desc": "It has no name because every name it is given is eaten. It is what lies beyond the map."},
]

const NOTES := [
	{"id": "n1", "title": "Torn Log, Day 1", "text": "Our charts show open sea here. Yet there is sand under my boots. The compass spins. The crew will not leave the boat."},
	{"id": "n2", "title": "Torn Log, Day 3", "text": "Found a village. Fires still warm. Bowls still full. No one. Not a single footprint leading away."},
	{"id": "n3", "title": "Carved Plank", "text": "THREE SHARDS LIGHT THE LAMP. THE LAMP KEEPS IT BELOW. IF THE LAMP GOES DARK, DO NOT SAY ITS NAME."},
	{"id": "n4", "title": "Corsair's Boast", "text": "Captain says the lamp shards are worth a kingdom. We pried them loose at dawn. By dusk, the sea went quiet."},
	{"id": "n5", "title": "Elder's Prayer", "text": "Light behind us, sea before us. Let what is unknown stay unknown. Let the island stay unseen."},
	{"id": "n6", "title": "Torn Log, Day 9", "text": "The shadows are the villagers. I am sure now. They wave before they attack. As if they remember me."},
	{"id": "n7", "title": "Torn Log, Last Page", "text": "If someone finds this: I tried to put the shards back. I failed. I am writing my name so I do not forget it. My name is ____."},
	{"id": "n8", "title": "Scorched Mural", "text": "The mural shows a figure with a lantern walking into the dark. The face has been scratched away. The figure looks like you."},
]

# ---------------------------------------------------------------- lifecycle
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_index_textures()
	_load_options()
	new_game()

func _setup_input() -> void:
	var map := {
		"up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT],
		# gameplay: X swings the sword, Q / E / Tab fire the three skills, F or Enter talks, Space dashes
		"attack": [KEY_X], "dash": [KEY_SPACE, KEY_SHIFT, KEY_K], "interact": [KEY_F, KEY_ENTER],
		"skill1": [KEY_Q], "skill2": [KEY_E], "skill3": [KEY_TAB],
		"menu": [KEY_ESCAPE, KEY_M],
		# menus & dialogue: Enter / Space / Z / F confirm, Esc / Backspace / X go back
		"ui_ok": [KEY_ENTER, KEY_SPACE, KEY_Z, KEY_F, KEY_KP_ENTER], "ui_back": [KEY_ESCAPE, KEY_BACKSPACE, KEY_X],
		"ui_u": [KEY_W, KEY_UP], "ui_d": [KEY_S, KEY_DOWN], "ui_l": [KEY_A, KEY_LEFT], "ui_r": [KEY_D, KEY_RIGHT],
	}
	var pads := {
		"up": [JOY_BUTTON_DPAD_UP], "down": [JOY_BUTTON_DPAD_DOWN], "left": [JOY_BUTTON_DPAD_LEFT], "right": [JOY_BUTTON_DPAD_RIGHT],
		"attack": [JOY_BUTTON_X], "dash": [JOY_BUTTON_B], "interact": [JOY_BUTTON_A], "skill1": [JOY_BUTTON_LEFT_SHOULDER],
		"skill2": [JOY_BUTTON_RIGHT_SHOULDER], "skill3": [JOY_BUTTON_Y], "menu": [JOY_BUTTON_START],
		"ui_ok": [JOY_BUTTON_A], "ui_back": [JOY_BUTTON_B, JOY_BUTTON_START],
		"ui_u": [JOY_BUTTON_DPAD_UP], "ui_d": [JOY_BUTTON_DPAD_DOWN], "ui_l": [JOY_BUTTON_DPAD_LEFT], "ui_r": [JOY_BUTTON_DPAD_RIGHT],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.4)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
		for b in pads.get(action, []):
			var jb := InputEventJoypadButton.new()
			jb.button_index = b
			InputMap.action_add_event(action, jb)
	var lm := InputEventMouseButton.new(); lm.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", lm)
	var rm := InputEventMouseButton.new(); rm.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("dash", rm)
	for pair in [["left", JOY_AXIS_LEFT_X, -1.0], ["right", JOY_AXIS_LEFT_X, 1.0], ["up", JOY_AXIS_LEFT_Y, -1.0], ["down", JOY_AXIS_LEFT_Y, 1.0]]:
		var jm := InputEventJoypadMotion.new()
		jm.axis = pair[1]; jm.axis_value = pair[2]
		InputMap.action_add_event(pair[0], jm)

func _index_textures() -> void:
	for d in SPRITE_DIRS:
		var dir := DirAccess.open("res://assets/sprites/" + d)
		if dir == null:
			continue
		for f in dir.get_files():
			var fname: String = f.trim_suffix(".import").trim_suffix(".remap")
			if fname.ends_with(".png"):
				_tex_index[fname.get_basename()] = "res://assets/sprites/%s/%s" % [d, fname]

func tex(name: String) -> Texture2D:
	if _tex_cache.has(name):
		return _tex_cache[name]
	var p: String = _tex_index.get(name, "")
	var t: Texture2D = null
	if p != "":
		t = load(p)
	if t == null:
		push_warning("missing texture " + name)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
		t = ImageTexture.create_from_image(img)
	_tex_cache[name] = t
	return t

func img(name: String) -> Image:
	var i: Image = tex(name).get_image()
	if i.is_compressed():
		i.decompress()
	i.convert(Image.FORMAT_RGBA8)
	return i

# ---------------------------------------------------------------- state
func new_game(player_name := "ARIN") -> void:
	data = {
		"name": player_name, "level": 1, "xp": 0, "hp": 100, "max_hp": 100, "mp": 60, "max_mp": 60,
		"atk": 10, "def": 2, "coins": 0, "items": {"mango": 2, "banana": 1}, "key_items": {},
		"flags": {}, "notes": [], "seen": {}, "defeated": {}, "area": "overworld", "pos": null,
		"checkpoint": {"area": "overworld", "pos": null}, "explored": {}, "time": 0.0, "opened": {},
		"skills": ["whirl"], "kills": 0,
	}

func _process(delta: float) -> void:
	if main and main.get("playing") and not get_tree().paused:
		data["time"] = float(data.get("time", 0.0)) + delta

func flag(k: String) -> bool:
	return bool(data["flags"].get(k, false))

func set_flag(k: String, v = true) -> void:
	data["flags"][k] = v

func is_opened(id: String) -> bool:
	return data["opened"].has(id)

func mark_opened(id: String) -> void:
	data["opened"][id] = true

func xp_to_next(lv: int = -1) -> int:
	if lv < 0:
		lv = int(data["level"])
	return int(40.0 * pow(lv, 1.45))

func add_xp(amount: int) -> void:
	data["xp"] = int(data["xp"]) + amount
	var leveled := false
	while int(data["xp"]) >= xp_to_next():
		data["xp"] = int(data["xp"]) - xp_to_next()
		data["level"] = int(data["level"]) + 1
		data["max_hp"] = int(data["max_hp"]) + 12
		data["max_mp"] = int(data["max_mp"]) + 6
		data["atk"] = int(data["atk"]) + 2
		data["def"] = int(data["def"]) + 1
		data["hp"] = data["max_hp"]
		data["mp"] = data["max_mp"]
		leveled = true
	if leveled:
		Sfx.play("levelup")
		toast.emit("LEVEL UP!  Lv %d" % data["level"], Color(1, 0.9, 0.3))
		if int(data["level"]) >= 3 and not data["skills"].has("bolt") and flag("mermaid_met"):
			pass
	stats_changed.emit()

func add_item(id: String, n := 1) -> void:
	data["items"][id] = int(data["items"].get(id, 0)) + n
	if int(data["items"][id]) <= 0:
		data["items"].erase(id)
	inventory_changed.emit()

func add_key_item(id: String, n := 1) -> void:
	data["key_items"][id] = int(data["key_items"].get(id, 0)) + n
	if int(data["key_items"][id]) <= 0:
		data["key_items"].erase(id)
	inventory_changed.emit()

func has_key_item(id: String) -> bool:
	return int(data["key_items"].get(id, 0)) > 0

func shard_count() -> int:
	var c := 0
	for s in ["tide_shard", "grove_shard", "ember_shard"]:
		if has_key_item(s):
			c += 1
	return c

func use_item(id: String) -> bool:
	if not ITEMS.has(id) or int(data["items"].get(id, 0)) <= 0:
		return false
	var it: Dictionary = ITEMS[id]
	if it.has("maxhp"):
		data["max_hp"] = int(data["max_hp"]) + int(it["maxhp"])
		data["hp"] = int(data["hp"]) + int(it["maxhp"])
	else:
		var full_hp := int(data["hp"]) >= int(data["max_hp"])
		var full_mp := int(data["mp"]) >= int(data["max_mp"])
		if (not it.has("mp") or full_mp) and (not it.has("hp") or full_hp):
			return false
		if it.has("hp"):
			data["hp"] = min(int(data["max_hp"]), int(data["hp"]) + int(it["hp"]))
		if it.has("mp"):
			data["mp"] = min(int(data["max_mp"]), int(data["mp"]) + int(it["mp"]))
	add_item(id, -1)
	Sfx.play("heal")
	stats_changed.emit()
	return true

func add_note(id: String) -> void:
	if not data["notes"].has(id):
		data["notes"].append(id)

func note_by_id(id: String) -> Dictionary:
	for n in NOTES:
		if n["id"] == id:
			return n
	return {}

func see(id: String) -> void:
	if not data["seen"].has(id):
		data["seen"][id] = true

func defeat(id: String) -> void:
	data["defeated"][id] = int(data["defeated"].get(id, 0)) + 1
	data["kills"] = int(data.get("kills", 0)) + 1

func time_string() -> String:
	var t := int(data.get("time", 0.0))
	return "%d:%02d" % [t / 3600, (t / 60) % 60]

# ---------------------------------------------------------------- save / load (3 journal slots)
const SLOTS := 3
var slot := 1

var test_mode := false   # developer test runs write to separate files and never touch real journals

func slot_path(s: int) -> String:
	return ("user://test_slot%d.json" if test_mode else "user://lanka_slot%d.json") % s

func _migrate_old_save() -> void:
	if FileAccess.file_exists(SAVE_PATH) and not FileAccess.file_exists(slot_path(1)):
		DirAccess.rename_absolute(SAVE_PATH, slot_path(1))

func has_save() -> bool:
	_migrate_old_save()
	for s in range(1, SLOTS + 1):
		if FileAccess.file_exists(slot_path(s)):
			return true
	return false

func slot_used(s: int) -> bool:
	return FileAccess.file_exists(slot_path(s))

func most_recent_slot() -> int:
	var best := -1
	var best_t := -1.0
	for s in range(1, SLOTS + 1):
		var d := peek_save(s)
		if not d.is_empty() and float(d.get("saved_at", 0.0)) > best_t:
			best_t = float(d.get("saved_at", 0.0))
			best = s
	return best

func save_game(s := -1) -> bool:
	if s > 0:
		slot = s
	if main and main.has_method("sync_area_to_save"):
		main.sync_area_to_save()
	data["saved_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(slot_path(slot), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true

func peek_save(s := -1) -> Dictionary:
	_migrate_old_save()
	if s < 0:
		s = most_recent_slot()
	if s < 0 or not FileAccess.file_exists(slot_path(s)):
		return {}
	var f := FileAccess.open(slot_path(s), FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}

func slot_summary(s: int) -> String:
	var d := peek_save(s)
	if d.is_empty():
		return ""
	var shards := 0
	for k in ["tide_shard", "grove_shard", "ember_shard"]:
		if d.get("key_items", {}).has(k):
			shards += 1
	var tt := int(d.get("time", 0.0))
	return "%s   Lv %d   %d:%02d   Shards %d/3" % [d.get("name", "?"), int(d.get("level", 1)), tt / 3600, (tt / 60) % 60, shards]

func load_game(s := -1) -> bool:
	if s < 0:
		s = most_recent_slot()
	var d := peek_save(s)
	if d.is_empty():
		return false
	slot = s
	new_game()
	for k in d:
		data[k] = d[k]
	# JSON turns ints into floats; normalise the important ones
	for k in ["level", "xp", "hp", "max_hp", "mp", "max_mp", "atk", "def", "coins", "kills"]:
		data[k] = int(data.get(k, 0))
	for dict_key in ["items", "key_items"]:
		var fixed := {}
		for k in data[dict_key]:
			fixed[k] = int(data[dict_key][k])
		data[dict_key] = fixed
	return true

func _load_options() -> void:
	var f := FileAccess.open("user://lanka_options.json", FileAccess.READ)
	if f:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for k in d:
				options[k] = d[k]
	apply_options()

func save_options() -> void:
	var f := FileAccess.open("user://lanka_options.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(options))
	apply_options()

func apply_options() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(max(0.001, float(options["volume"]))))

# ---------------------------------------------------------------- UI style: "Lantern & Ink"
# Dark ink panels, a single gold hairline, parchment lettering, ink pages for the journal.
const C_TEXT := Color("efe3c4")      # parchment text on ink
const C_SHADOW := Color(0, 0, 0, 0.7)
const C_BOX := Color(0.075, 0.065, 0.11, 0.94)
const C_BORDER := Color("c8a050")    # lantern gold
const C_BORDER2 := Color("7a5a28")
const C_GOLD := Color("f0c860")
const C_DIM := Color("8f8670")
const C_INK := Color("2b2118")       # ink on parchment pages
const C_PAGE := Color("e9dcb8")

func box_style(border := C_BORDER, fill := C_BOX) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fill
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(1)
	s.content_margin_left = 10; s.content_margin_right = 10
	s.content_margin_top = 6; s.content_margin_bottom = 6
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 4
	return s

func make_box(border := C_BORDER, fill := C_BOX) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box_style(border, fill))
	return p

func make_label(text := "", size := 10, color := C_TEXT, shadow := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if shadow:
		l.add_theme_color_override("font_shadow_color", Color(1, 1, 1, 0.0) if color.v < 0.4 else C_SHADOW)
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
	return l

func shake(amount: float) -> void:
	if options["shake"] and main and main.has_method("shake"):
		main.shake(amount)
