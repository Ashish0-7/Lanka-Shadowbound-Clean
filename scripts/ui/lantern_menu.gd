class_name LanternMenu
extends Control
## Pause menu built from two concentric rings around a burning lantern.
##  • Outer ring: the eight sections (Chart, Satchel, Bestiary, …). Turn it to choose.
##  • Inner ring: picking a section slides the wheel left and spins up an inner ring of that
##    section's own options (items, creatures, pages, journals, settings…). The chosen option
##    points at a detail panel on the right. Z acts on it, X steps back out.

const ENTRIES := [
	{"id": "map", "name": "Chart", "icon": "treasure_x_mark", "desc": "The island, as far as your lantern has reached."},
	{"id": "satchel", "name": "Satchel", "icon": "crate", "desc": "Supplies, relics and the techniques you have learned."},
	{"id": "bestiary", "name": "Bestiary", "icon": "crab_1", "desc": "Notes on the shadow-touched things that walk this island."},
	{"id": "pages", "name": "Lost Pages", "icon": "message_bottle", "desc": "Messages the sea has carried to you."},
	{"id": "explorer", "name": "Warrior", "icon": "hero", "desc": "Your strength, your progress, your story so far."},
	{"id": "settings", "name": "Settings", "icon": "anchor", "desc": "Text speed, volume, screen shake, and the controls."},
	{"id": "save", "name": "Inscribe", "icon": "campfire_1", "desc": "Write this journey into one of three journals."},
	{"id": "title", "name": "Leave Isle", "icon": "rowboat", "desc": "Return to the title screen to load another journal or begin anew."},
]
const BEAST_TEX := {"shadow_crab": "crab_1", "shadow_gull": "seagull_1", "shadow_jelly": "jellyfish_1", "shadow_monkey": "monkey", "shadow_hermit": "hermit_crab",
	"shadow_pirate": "pirate", "shadow_dancer": "tribal_dancer", "tide_king": "crab_2", "ape_alpha": "monkey", "nameless": "hero"}

const C_HOME := Vector2(240, 120)
const C_SIDE := Vector2(122, 136)
const RING := 78.0
const PANEL := Rect2(238, 34, 232, 206)

var mode := "wheel"     # wheel | sub
var sel := 0            # outer selection
var ang := 0.0
var sub_sel := 0        # inner selection
var sub_ang := 0.0
var subs: Array = []    # inner options for the chosen section
var section := ""
var slide := 0.0        # 0 = wheel centred, 1 = wheel at the side with inner ring open
var t := 0.0
var open_t := 0.0
var open_frame := -1
var busy := false

var wheel_ui: Control
var panel_ui: Control
var name_label: Label
var desc_label: Label
var hint_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# ================================================================== open / close
func open() -> void:
	visible = true
	mode = "wheel"
	slide = 0.0
	open_t = 0.0
	open_frame = Engine.get_process_frames()
	ang = _outer_target()
	Sfx.play("menu")
	get_tree().paused = true
	_build()

## Jump straight into a section's inner ring (used by the autotest).
func open_book(id: String) -> void:
	if not visible:
		open()
	for i in ENTRIES.size():
		if ENTRIES[i]["id"] == id:
			sel = i
	_enter_section()

func close() -> void:
	visible = false
	for c in get_children():
		c.queue_free()
	Sfx.play("cancel")
	get_tree().paused = false
	if Game.main and Game.main.area and Game.main.area.player:
		Game.main.area.player.interact_lock = 0.25

func _center() -> Vector2:
	var k := slide * slide * (3.0 - 2.0 * slide)
	return C_HOME.lerp(C_SIDE, k)

func _outer_target() -> float:
	# in the wheel the chosen sigil sits at the top; with the inner ring open it swings to the right
	var base := -PI / 2.0 if mode == "wheel" else 0.0
	return base - sel * TAU / ENTRIES.size()

func _inner_target() -> float:
	return 0.0 - sub_sel * TAU / maxi(1, subs.size())

func _inner_radius() -> float:
	return clampf(subs.size() * 26.0 / TAU, 38.0, 60.0)

# ================================================================== build (labels)
func _build() -> void:
	for c in get_children():
		c.queue_free()
	wheel_ui = Control.new()
	wheel_ui.size = Vector2(480, 270)
	wheel_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wheel_ui)
	panel_ui = Control.new()
	panel_ui.size = Vector2(480, 270)
	panel_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel_ui)
	var d := Game.data
	var who := Game.make_label("%s   ·   Lv %d" % [d["name"], d["level"]], 10, Game.C_GOLD)
	who.position = Vector2(14, 8)
	wheel_ui.add_child(who)
	var st := Game.make_label("HP %d/%d    MP %d/%d    ◆ %d/3    %s" % [d["hp"], d["max_hp"], d["mp"], d["max_mp"], Game.shard_count(), Game.time_string()], 8, Game.C_TEXT)
	st.position = Vector2(14, 22)
	wheel_ui.add_child(st)
	name_label = Game.make_label("", 15, Game.C_GOLD)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wheel_ui.add_child(name_label)
	desc_label = Game.make_label("", 9, Game.C_TEXT)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wheel_ui.add_child(desc_label)
	hint_label = Game.make_label("", 8, Game.C_DIM)
	hint_label.position = Vector2(0, 256)
	hint_label.size = Vector2(480, 12)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wheel_ui.add_child(hint_label)
	if mode == "wheel":
		var a: GameArea = Game.main.area if Game.main else null
		if a:
			var where := Game.make_label(a.current_region if a.current_region != "" else a.display_name, 10, Game.C_GOLD)
			where.position = Vector2(266, 8)
			where.size = Vector2(200, 14)
			where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			wheel_ui.add_child(where)
			var ex := Game.make_label("%d%% of %s charted" % [int(a.explored_ratio() * 100.0), a.display_name], 8, Game.C_TEXT)
			ex.position = Vector2(266, 22)
			ex.size = Vector2(200, 12)
			ex.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			wheel_ui.add_child(ex)
	_refresh_text()

func _refresh_text() -> void:
	sub_sel = clampi(sub_sel, 0, maxi(0, subs.size() - 1))
	if mode == "wheel":
		name_label.text = "—  %s  —" % ENTRIES[sel]["name"]
		name_label.position = Vector2(0, 210)
		name_label.size = Vector2(480, 20)
		desc_label.text = ENTRIES[sel]["desc"]
		desc_label.position = Vector2(60, 232)
		desc_label.size = Vector2(360, 14)
		hint_label.text = "◂ ▸  turn the wheel      Z  open      X  resume"
	else:
		name_label.text = ENTRIES[sel]["name"]
		name_label.position = Vector2(C_SIDE.x - 100, 228)
		name_label.size = Vector2(200, 20)
		desc_label.text = ""
		var act := _action_word()
		hint_label.text = "◂ ▸  turn the inner ring      %sX  back to the wheel" % ("" if act == "—" else "Z  %s      " % act)
		_build_panel()

# ================================================================== sections → inner options
func _enter_section() -> void:
	section = ENTRIES[sel]["id"]
	subs = _make_subs(section)
	sub_sel = 0
	if section == "save":
		sub_sel = clampi(Game.slot - 1, 0, subs.size() - 1)
	sub_ang = _inner_target() + PI  # spin in from the opposite side
	mode = "sub"
	Sfx.play("select")
	_build()

func _exit_section() -> void:
	mode = "wheel"
	Sfx.play("cancel")
	_build()

func _make_subs(id: String) -> Array:
	var out := []
	match id:
		"map":
			out.append({"name": "You are here", "icon": "hero", "focus": "player"})
			var a: GameArea = Game.main.area
			for lm in a.landmarks:
				var c: Vector2i = lm["cell"]
				var known := a.explored[c.y * a.W + c.x] != 0
				out.append({"name": lm["name"] if known else "Uncharted", "icon": "treasure_x_mark", "focus": c if known else null, "dim": not known})
		"satchel":
			for id2 in Game.ITEMS:
				var n := int(Game.data["items"].get(id2, 0))
				if n > 0:
					var it: Dictionary = Game.ITEMS[id2]
					out.append({"name": it["name"], "icon": it["icon"], "kind": "item", "id": id2, "count": n, "desc": it["desc"], "group": "Supply"})
			for id2 in Game.KEY_ITEMS:
				var n2 := int(Game.data["key_items"].get(id2, 0))
				if n2 > 0:
					var it2: Dictionary = Game.KEY_ITEMS[id2]
					out.append({"name": it2["name"], "icon": it2["icon"], "kind": "relic", "id": id2, "count": n2 if id2 == "key" else 0, "desc": it2["desc"], "tint": it2.get("tint", Color.WHITE), "group": "Relic"})
			for id2 in Game.data["skills"]:
				var s: Dictionary = Game.SKILLS[id2]
				out.append({"name": s["name"], "icon": Hud.SLOT_ICONS[id2], "kind": "skill", "desc": "%s\n\nKey [%s]   ·   MP %d   ·   cooldown %.1fs" % [s["desc"], s["key"], s["cost"], s["cd"]], "group": "Technique"})
			if out.is_empty():
				out.append({"name": "Empty", "icon": "crate", "dim": true, "desc": "Your satchel is empty."})
		"bestiary":
			for e in Game.CODEX:
				var seen: bool = Game.data["seen"].has(e["id"])
				out.append({"name": e["name"] if seen else "? ? ? ? ?", "icon": BEAST_TEX.get(e["id"], "crab_1"), "beast": e, "seen": seen,
					"tint": Color(0.75, 0.5, 1.0) if seen else Color(0, 0, 0, 0.95)})
		"pages":
			for n3 in Game.NOTES:
				var k: bool = Game.data["notes"].has(n3["id"])
				out.append({"name": n3["title"] if k else "Missing page", "icon": "message_bottle", "note": n3, "dim": not k})
		"explorer":
			out.append({"name": "Vitals", "icon": "hero", "view": "vitals"})
			out.append({"name": "Progress", "icon": "treasure_x_mark", "view": "progress"})
			out.append({"name": "Lamp Shards", "icon": "pearl_oyster", "view": "shards", "tint": Color(1, 0.9, 0.6)})
			out.append({"name": "Techniques", "icon": "seashell_spiral", "view": "skills"})
		"settings":
			out.append({"name": "Text speed", "icon": "wooden_sign", "set": "text_speed"})
			out.append({"name": "Volume", "icon": "seashell_spiral", "set": "volume"})
			out.append({"name": "Screen shake", "icon": "rock_big", "set": "shake"})
			out.append({"name": "Controls", "icon": "fishing_rod", "set": "controls"})
		"save":
			for s2 in range(1, Game.SLOTS + 1):
				out.append({"name": "Journal %d" % s2, "icon": "campfire_1" if Game.slot_used(s2) else "message_bottle", "slot": s2, "dim": not Game.slot_used(s2)})
		"title":
			out.append({"name": "Leave the isle", "icon": "rowboat", "leave": true})
			out.append({"name": "Stay a while", "icon": "campfire_1", "leave": false})
	return out

func _action_word() -> String:
	if subs.is_empty():
		return "—"
	var o: Dictionary = subs[sub_sel]
	match section:
		"satchel": return "use" if o.get("kind", "") == "item" else "—"
		"settings": return "change" if o.get("set", "") != "controls" else "—"
		"save": return "inscribe"
		"title": return "choose"
		"pages": return "read aloud" if not o.get("dim", false) else "—"
	return "—"

# ================================================================== detail panel
func _txt(text: String, pos: Vector2, size := 10, col := Game.C_TEXT, width := 0.0) -> Label:
	var l := Game.make_label(text, size, col)
	l.position = PANEL.position + pos
	if width > 0.0:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(width, 0)
	panel_ui.add_child(l)
	if width > 0.0:
		l.size = Vector2(width, 0)  # must be set after entering the tree for autowrap to take
	return l

func _row(label: String, value: String, y: float) -> void:
	_txt(label, Vector2(12, y), 10)
	var v := _txt(value, Vector2(12, y), 10, Game.C_GOLD)
	v.size = Vector2(PANEL.size.x - 24, 12)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func _pic(tex: Texture2D, r: Rect2, mod := Color.WHITE, mat: Material = null) -> void:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.position = PANEL.position + r.position
	tr.size = r.size
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.modulate = mod
	tr.material = mat
	panel_ui.add_child(tr)

func _build_panel() -> void:
	for c in panel_ui.get_children():
		c.queue_free()
	if subs.is_empty():
		return
	var o: Dictionary = subs[sub_sel]
	var w := PANEL.size.x - 24
	_txt(o["name"], Vector2(12, 8), 13, Game.C_GOLD)
	_txt("%d / %d" % [sub_sel + 1, subs.size()], Vector2(PANEL.size.x - 44, 11), 8, Game.C_DIM)
	var d := Game.data
	match section:
		"map":
			var mv := MapView.new()
			mv.area = Game.main.area
			mv.position = PANEL.position + Vector2(8, 30)
			mv.size = Vector2(PANEL.size.x - 16, 150)
			if o.get("focus") is Vector2i:
				mv.focus_cell = o["focus"]
			elif typeof(o.get("focus")) == TYPE_STRING:
				mv.focus_cell = Game.main.area.cell_of(Game.main.area.player.global_position)
			panel_ui.add_child(mv)
			_txt("%d%% of %s charted" % [int(Game.main.area.explored_ratio() * 100.0), Game.main.area.display_name], Vector2(12, 184), 9, Game.C_TEXT)
		"satchel":
			_txt(o.get("group", ""), Vector2(12, 24), 8, Game.C_DIM)
			_pic(Game.tex(o["icon"]), Rect2(PANEL.size.x / 2 - 28, 38, 56, 56), o.get("tint", Color.WHITE))
			if int(o.get("count", 0)) > 0:
				_txt("×%d" % o["count"], Vector2(PANEL.size.x / 2 + 30, 80), 11, Game.C_GOLD)
			_txt(o.get("desc", ""), Vector2(12, 102), 10, Game.C_TEXT, w)
			if o.get("kind", "") == "item":
				_txt("Z  use or discard", Vector2(12, 186), 9, Game.C_GOLD)
		"bestiary":
			var e: Dictionary = o["beast"]
			if o["seen"]:
				_pic(Game.tex(o["icon"]), Rect2(PANEL.size.x / 2 - 36, 28, 72, 72), Color.WHITE, FX.make_actor_material(true, Color(0.42, 0.18, 0.62)))
				_txt(e["desc"], Vector2(12, 106), 10, Game.C_TEXT, w)
				_txt("Calmed: %d" % int(d["defeated"].get(e["id"], 0)), Vector2(12, 186), 9, Game.C_GOLD)
			else:
				_pic(Game.tex(o["icon"]), Rect2(PANEL.size.x / 2 - 36, 28, 72, 72), Color(0, 0, 0, 0.95))
				_txt("Unknown. No one has seen this and lived to describe it.", Vector2(12, 106), 10, Game.C_DIM, w)
		"pages":
			var n: Dictionary = o["note"]
			if o.get("dim", false):
				_txt("This page is still out there. The sea carries bottles to every shore, cave and ruin.", Vector2(12, 32), 10, Game.C_DIM, w)
			else:
				var body: String = n["text"]
				if n["id"] == "n7":
					body = body.replace("____", str(d["name"]))
				_txt(body, Vector2(12, 32), 10, Color("dcd2ff"), w)
		"explorer":
			match o["view"]:
				"vitals":
					_pic(Game.tex("hero"), Rect2(12, 28, 40, 40))
					_txt("%s\nLevel %d   ·   XP %d/%d" % [d["name"], d["level"], d["xp"], Game.xp_to_next()], Vector2(60, 32), 10)
					var y := 76.0
					for r in [["Health", "%d / %d" % [d["hp"], d["max_hp"]]], ["Spirit (MP)", "%d / %d" % [d["mp"], d["max_mp"]]], ["Attack", str(d["atk"])], ["Defense", str(d["def"])], ["Coins", str(d["coins"])], ["Time on the isle", Game.time_string()]]:
						_row(r[0], r[1], y); y += 17
				"progress":
					var y2 := 32.0
					for r in [["Island charted", "%d%%" % int(Game.main.overworld_explored() * 100.0)], ["Lamp shards", "%d / 3" % Game.shard_count()], ["Lost pages", "%d / %d" % [d["notes"].size(), Game.NOTES.size()]],
							["Beasts recorded", "%d / %d" % [d["seen"].size(), Game.CODEX.size()]], ["Shadows calmed", str(d.get("kills", 0))], ["Journal", "No. %d" % Game.slot]]:
						_row(r[0], r[1], y2); y2 += 18
				"shards":
					var sx := 30.0
					for s in ["tide_shard", "grove_shard", "ember_shard"]:
						var have := Game.has_key_item(s)
						_pic(Game.tex("pearl_oyster"), Rect2(sx, 34, 48, 48), Game.KEY_ITEMS[s]["tint"] if have else Color(0.2, 0.2, 0.25, 0.6))
						var sl_lbl := _txt(Game.KEY_ITEMS[s]["name"].replace(" Shard", "") if have else "?", Vector2(sx, 86), 9, Game.C_GOLD if have else Game.C_DIM)
						sl_lbl.size = Vector2(48, 12)
						sx += 60
					_txt("Three shards light the Great Lamp. Two open the lighthouse.", Vector2(12, 112), 10, Game.C_TEXT, w)
				"skills":
					var y3 := 30.0
					for id in ["whirl", "bolt", "radiant"]:
						var s2: Dictionary = Game.SKILLS[id]
						var has: bool = d["skills"].has(id)
						_txt("[%s] %s" % [s2["key"], s2["name"] if has else "? ? ?"], Vector2(12, y3), 10, Game.C_GOLD if has else Game.C_DIM)
						_txt(s2["desc"] if has else "Not yet learned.", Vector2(12, y3 + 13), 8, Game.C_TEXT if has else Game.C_DIM, w)
						y3 += 50
		"settings":
			var opt := Game.options
			match o["set"]:
				"text_speed":
					_txt(["Slow", "Medium", "Fast"][int(opt["text_speed"])], Vector2(12, 40), 16, Game.C_GOLD)
					_txt("How quickly words appear when someone speaks.", Vector2(12, 70), 10, Game.C_TEXT, w)
				"volume":
					var v := int(round(float(opt["volume"]) * 10.0))
					_txt("▮".repeat(v) + "▯".repeat(10 - v), Vector2(12, 40), 16, Game.C_GOLD)
					_txt("Music and sound volume. Z raises it; it wraps back to silence after full.", Vector2(12, 70), 10, Game.C_TEXT, w)
				"shake":
					_txt("On" if opt["shake"] else "Off", Vector2(12, 40), 16, Game.C_GOLD)
					_txt("Camera shake on hits, slams and boss roars.", Vector2(12, 70), 10, Game.C_TEXT, w)
				"controls":
					_txt("Move ........ WASD / arrows\nSword ....... X / left click\nDash ........ Space / Shift / right click\nSkills ...... Q   E   Tab\nTalk, use ... F / Enter\nThis menu ... Esc / M", Vector2(12, 32), 9, Game.C_TEXT, w)
		"save":
			var s3: int = o["slot"]
			var summ := Game.slot_summary(s3)
			if summ == "":
				_txt("Blank pages.", Vector2(12, 34), 11, Game.C_DIM)
				_txt("Z  inscribe your journey here.", Vector2(12, 186), 9, Game.C_GOLD)
			else:
				var sd := Game.peek_save(s3)
				var where := "Lanka Isle" if str(sd.get("area", "overworld")) == "overworld" else str(sd.get("area", "")).capitalize()
				_txt(summ.replace("   ", "\n") + "\nLast seen: " + where, Vector2(12, 34), 10, Game.C_TEXT, w)
				_txt("Z  update this journal" if s3 == Game.slot else "Z  write over this journal", Vector2(12, 186), 9, Game.C_GOLD)
			if s3 == Game.slot:
				var cj := _txt("current journal", Vector2(PANEL.size.x - 100, 34), 8, Game.C_GOLD)
				cj.size = Vector2(88, 12)
		"title":
			if o["leave"]:
				_txt("Return to the title screen. From there you can open another journal or begin a new journey.\n\nAnything not inscribed in a journal will be lost.", Vector2(12, 34), 10, Game.C_TEXT, w)
			else:
				_txt("Stay on the island and keep exploring.", Vector2(12, 34), 10, Game.C_TEXT, w)

# ================================================================== actions
func _act() -> void:
	if subs.is_empty():
		return
	var o: Dictionary = subs[sub_sel]
	match section:
		"satchel":
			if o.get("kind", "") != "item":
				Sfx.play("cancel")
				return
			busy = true
			var c: int = await Game.main.dialog.choose("%s: what will you do?" % o["name"], ["Use", "Discard", "Keep"])
			if c == 0:
				if Game.use_item(o["id"]):
					await Game.main.dialog.say(["You used the %s.  HP %d/%d   MP %d/%d" % [o["name"], Game.data["hp"], Game.data["max_hp"], Game.data["mp"], Game.data["max_mp"]]])
				else:
					await Game.main.dialog.say(["It would do nothing right now."])
			elif c == 1:
				Game.add_item(o["id"], -1)
			busy = false
			get_tree().paused = true
			_reload_subs()
		"settings":
			var opt := Game.options
			match o["set"]:
				"text_speed": opt["text_speed"] = (int(opt["text_speed"]) + 1) % 3
				"volume": opt["volume"] = 0.0 if float(opt["volume"]) >= 0.95 else float(opt["volume"]) + 0.1
				"shake": opt["shake"] = not opt["shake"]
				_: return
			Game.save_options()
			Sfx.play("select")
			_build_panel()
		"pages":
			if not o.get("dim", false):
				busy = true
				var n: Dictionary = o["note"]
				await Game.main.dialog.say([n["title"], n["text"].replace("____", str(Game.data["name"]))])
				busy = false
				get_tree().paused = true
		"save":
			busy = true
			var s: int = o["slot"]
			var q := "Inscribe your journey into Journal %d?" % s
			if Game.slot_used(s) and s != Game.slot:
				q = "Journal %d already holds another journey. Write over it?" % s
			elif Game.slot_used(s):
				q = "Update Journal %d with your journey so far?" % s
			var yes: bool = await Game.main.dialog.ask(q)
			if yes:
				if Game.save_game(s):
					Sfx.play("levelup")
					await Game.main.dialog.say(["Your journey is inscribed in Journal %d." % s])
				else:
					await Game.main.dialog.say(["The ink will not take. The island refuses to be written down."])
			busy = false
			get_tree().paused = true
			_reload_subs()
		"title":
			if o["leave"]:
				visible = false
				for c in get_children():
					c.queue_free()
				Game.main.return_to_title()
			else:
				close()

func _reload_subs() -> void:
	subs = _make_subs(section)
	sub_sel = clampi(sub_sel, 0, maxi(0, subs.size() - 1))
	_build()

# ================================================================== input
func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	open_t += delta
	slide = move_toward(slide, 1.0 if mode == "sub" else 0.0, delta * 4.0)
	ang = lerp_angle(ang, _outer_target(), minf(1.0, delta * 10.0))
	sub_ang = lerp_angle(sub_ang, _inner_target(), minf(1.0, delta * 10.0))
	queue_redraw()
	if busy or (Game.main and Game.main.dialog.is_open()):
		return
	if Engine.get_process_frames() == open_frame:
		return
	var n := ENTRIES.size()
	if mode == "wheel":
		if Input.is_action_just_pressed("ui_r") or Input.is_action_just_pressed("ui_d"):
			sel = (sel + 1) % n; Sfx.play("blip"); _refresh_text()
		elif Input.is_action_just_pressed("ui_l") or Input.is_action_just_pressed("ui_u"):
			sel = (sel - 1 + n) % n; Sfx.play("blip"); _refresh_text()
		elif Input.is_action_just_pressed("ui_back") or Input.is_action_just_pressed("menu"):
			close()
		elif Input.is_action_just_pressed("ui_ok"):
			_enter_section()
	else:
		var m := maxi(1, subs.size())
		if Input.is_action_just_pressed("ui_r") or Input.is_action_just_pressed("ui_d"):
			sub_sel = (sub_sel + 1) % m; Sfx.play("blip"); _refresh_text()
		elif Input.is_action_just_pressed("ui_l") or Input.is_action_just_pressed("ui_u"):
			sub_sel = (sub_sel - 1 + m) % m; Sfx.play("blip"); _refresh_text()
		elif Input.is_action_just_pressed("ui_back") or Input.is_action_just_pressed("menu"):
			_exit_section()
		elif Input.is_action_just_pressed("ui_ok"):
			_act()

# ================================================================== drawing
func _diamond(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)

func _sigil(p: Vector2, r: float, tex: Texture2D, chosen: bool, col: Color, alpha: float) -> void:
	if chosen:
		draw_circle(p, r + 5 + sin(t * 5.0) * 1.5, Color(1, 0.75, 0.3, 0.18 * alpha))
	draw_circle(p, r, Color(0.08, 0.06, 0.12, 0.95 * alpha))
	var g := Game.C_GOLD if chosen else Game.C_BORDER
	draw_arc(p, r, 0, TAU, 32, Color(g.r, g.g, g.b, (1.0 if chosen else 0.7) * alpha), 1.5 if chosen else 1.0)
	var s := r * 1.25
	draw_texture_rect(tex, Rect2(p - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(col.r, col.g, col.b, col.a * alpha))

func _draw() -> void:
	var k := 1.0 - pow(1.0 - clampf(open_t * 3.0, 0.0, 1.0), 3.0)
	draw_rect(Rect2(0, 0, 480, 270), Color(0.02, 0.015, 0.04, 0.74 * k))
	var c := _center()
	var sl := slide
	# lantern glow at the hub
	var pulse := 0.85 + 0.15 * sin(t * 3.0)
	for i in range(6, 0, -1):
		draw_circle(c, 14.0 * i * pulse * k * (1.0 - 0.3 * sl), Color(1.0, 0.7, 0.3, 0.035))
	draw_texture_rect(Game.tex("tiki_torch"), Rect2(c - Vector2(12, 17), Vector2(24, 24)) if sl > 0.5 else Rect2(c - Vector2(16, 22), Vector2(32, 32)), false, Color(1, 1, 1, k))
	# ---- outer ring (grows outward and dims while an inner ring is open)
	var rr := RING * k + sl * 10.0
	var oa := 1.0 - 0.45 * sl
	draw_arc(c, rr, 0, TAU, 64, Color(Game.C_BORDER.r, Game.C_BORDER.g, Game.C_BORDER.b, 0.55 * k * oa), 1.0)
	draw_arc(c, rr + 22, 0, TAU, 64, Color(Game.C_BORDER.r, Game.C_BORDER.g, Game.C_BORDER.b, 0.15 * k * oa), 1.0)
	for i in 24:
		var a := t * 0.15 + TAU * i / 24.0
		var p := c + Vector2.from_angle(a) * (rr + 22)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 0.8, 0.4, 0.3 * k * oa))
	var n := ENTRIES.size()
	for i in n:
		var a := ang + TAU * i / n
		var p := c + Vector2.from_angle(a) * rr
		var chosen := i == sel
		var r := (17.0 if chosen else 12.0) * (1.0 - 0.25 * sl)
		var col := Color(1, 1, 1) if chosen else Color(0.75, 0.72, 0.7, 0.8)
		if ENTRIES[i]["id"] == "bestiary":
			col = Color(0.65, 0.4, 0.95)
		_sigil(p, r, Game.tex(ENTRIES[i]["icon"]), chosen, col, k * (1.0 if chosen else oa))
		if chosen and sl < 0.5:
			draw_line(c + Vector2.from_angle(a) * 22, p - Vector2.from_angle(a) * (r + 2), Color(1, 0.8, 0.4, 0.5), 1.0)
	# ---- inner ring
	if sl > 0.01 and subs.size() > 0:
		var ir := _inner_radius() * sl
		draw_arc(c, ir, 0, TAU, 48, Color(Game.C_GOLD.r, Game.C_GOLD.g, Game.C_GOLD.b, 0.45 * sl), 1.0)
		var m := subs.size()
		var sr := clampf(ir * PI / m * 0.75, 6.0, 12.0)
		for i in m:
			var a2 := sub_ang + TAU * i / m
			var p2 := c + Vector2.from_angle(a2) * ir
			var chosen2 := i == sub_sel
			var o: Dictionary = subs[i]
			var col2: Color = o.get("tint", Color.WHITE)
			if o.get("dim", false):
				col2 = Color(0.45, 0.42, 0.4, 0.6)
			_sigil(p2, sr * (1.35 if chosen2 else 1.0), Game.tex(o["icon"]), chosen2, col2, sl)
		# pointer from the chosen inner sigil to the detail panel
		var tip := c + Vector2.from_angle(sub_ang + TAU * sub_sel / m) * (ir + sr * 1.35 + 2)
		var to := Vector2(PANEL.position.x, clampf(tip.y, PANEL.position.y + 10, PANEL.end.y - 10))
		draw_line(tip, to, Color(1, 0.8, 0.4, 0.6 * sl), 1.0)
		_diamond(to, 3.0, Color(Game.C_GOLD.r, Game.C_GOLD.g, Game.C_GOLD.b, sl))
		# detail panel
		var pr := PANEL
		pr.position.x += (1.0 - sl) * 40.0
		draw_rect(pr.grow(4), Color(0, 0, 0, 0.3 * sl))
		draw_rect(pr, Color(0.06, 0.05, 0.09, 0.94 * sl))
		var g := Color(Game.C_BORDER.r, Game.C_BORDER.g, Game.C_BORDER.b, sl)
		draw_line(pr.position + Vector2(6, 0), Vector2(pr.end.x - 6, pr.position.y), g, 1.0)
		draw_line(Vector2(pr.position.x + 6, pr.end.y), pr.end - Vector2(6, 0), g, 1.0)
		for q in [pr.position + Vector2(4, 0), Vector2(pr.end.x - 4, pr.position.y), Vector2(pr.position.x + 4, pr.end.y), pr.end - Vector2(4, 0)]:
			_diamond(q, 2.5, g)
		draw_line(pr.position + Vector2(10, 24), Vector2(pr.end.x - 10, pr.position.y + 24), Color(g.r, g.g, g.b, 0.35 * sl), 1.0)
		panel_ui.modulate.a = sl
