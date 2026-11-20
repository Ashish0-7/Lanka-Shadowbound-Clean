class_name TitleScreen
extends Control
## Title: night sea, drifting logo, a lantern-marked menu, journal (save slot) picker
## and a name-signing page.

signal chosen(action: String, player_name: String, slot: int)

var t := 0.0
var stage := "intro"   # intro | menu | slots | name
var cursor := 0
var options: Array = []
var ui: Control
var name_str := ""
var grid_i := 0
var slot_mode := "load"   # load | new
var slot_i := 0
var confirm_overwrite := false
var stars: Array = []
var water: TextureRect
var logo: Label
var hint: Label
var brand: Control
var overlay: Control
const LETTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("070818")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	for i in 70:
		stars.append(Vector3(randf() * 480, randf() * 150, randf()))
	water = TextureRect.new()
	water.texture = Game.tex("water_deep")
	water.stretch_mode = TextureRect.STRETCH_TILE
	water.position = Vector2(-32, 168)
	water.size = Vector2(560, 120)
	water.modulate = Color(0.35, 0.4, 0.75)
	add_child(water)
	brand = Control.new()
	brand.size = Vector2(480, 270)
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(brand)
	logo = Game.make_label("LANKA", 46, Game.C_GOLD, false)
	logo.add_theme_color_override("font_outline_color", Color("3a1850"))
	logo.add_theme_constant_override("outline_size", 10)
	logo.position = Vector2(0, 22)
	logo.size = Vector2(480, 56)
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(logo)
	var sub := Game.make_label("S H A D O W B O U N D", 14, Color("c890ff"), false)
	sub.add_theme_color_override("font_outline_color", Color("10081c"))
	sub.add_theme_constant_override("outline_size", 6)
	sub.position = Vector2(0, 80)
	sub.size = Vector2(480, 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(sub)
	var tag := Game.make_label("an island that appears on no map", 9, Color(0.7, 0.75, 0.9), false)
	tag.position = Vector2(0, 101)
	tag.size = Vector2(480, 14)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_child(tag)
	hint = Game.make_label("press any key to light the lantern", 10, Game.C_TEXT, false)
	hint.position = Vector2(0, 205)
	hint.size = Vector2(480, 16)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)
	var foot := Game.make_label("PixelForge 2026  ·  THE UNKNOWN", 8, Color(0.55, 0.55, 0.7), false)
	foot.position = Vector2(0, 256)
	foot.size = Vector2(480, 12)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(foot)
	overlay = Control.new()
	overlay.size = Vector2(480, 270)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	ui = Control.new()
	ui.size = Vector2(480, 270)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	Sfx.play_music("title")

func _process(delta: float) -> void:
	t += delta
	water.position.x = -32 + fmod(t * 6.0, 16.0)
	water.position.y = 168 + sin(t * 0.8) * 2.0
	logo.position.y = 22 + sin(t * 1.4) * 3.0
	hint.visible = stage == "intro"
	brand.visible = stage == "intro" or stage == "menu"
	overlay.queue_redraw()
	hint.modulate.a = 0.45 + 0.55 * absf(sin(t * 1.8))
	queue_redraw()
	match stage:
		"intro":
			if t > 0.4 and (Input.is_action_just_pressed("ui_ok") or Input.is_action_just_pressed("menu") or Input.is_action_just_pressed("ui_back")):
				Sfx.play("select")
				_open_menu()
		"menu":
			_menu_input()
		"slots":
			_slots_input()
		"name":
			_name_blink()

func _input(event: InputEvent) -> void:
	if stage == "intro" and t > 0.4 and event.is_pressed() and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventMouseButton):
		Sfx.play("select")
		_open_menu()
		get_viewport().set_input_as_handled()
		return
	if stage == "name":
		_name_event(event)

## Name signing is event-driven so real keyboard typing works:
## letters type, Backspace erases, Enter signs, Esc steps back.
## Arrow keys / a gamepad still drive the on-screen letter grid.
func _name_event(event: InputEvent) -> void:
	var keys := _keys()
	var n := keys.size()
	var changed := false
	if event is InputEventKey and event.pressed:
		var kc: int = event.keycode
		if kc >= KEY_A and kc <= KEY_Z:
			if name_str.length() < 7:
				name_str += char(kc)
				Sfx.play("blip")
			changed = true
		elif kc == KEY_BACKSPACE or kc == KEY_DELETE:
			name_str = name_str.substr(0, maxi(0, name_str.length() - 1))
			Sfx.play("cancel")
			changed = true
		elif kc == KEY_ENTER or kc == KEY_KP_ENTER:
			_sign()
			get_viewport().set_input_as_handled()
			return
		elif kc == KEY_ESCAPE:
			Sfx.play("cancel")
			_open_slots("new")
			get_viewport().set_input_as_handled()
			return
		elif kc == KEY_RIGHT: grid_i = (grid_i + 1) % n; changed = true; Sfx.play("blip")
		elif kc == KEY_LEFT: grid_i = (grid_i - 1 + n) % n; changed = true; Sfx.play("blip")
		elif kc == KEY_DOWN: grid_i = mini(n - 1, grid_i + 7); changed = true; Sfx.play("blip")
		elif kc == KEY_UP: grid_i = maxi(0, grid_i - 7); changed = true; Sfx.play("blip")
		elif kc == KEY_SPACE:
			_press_grid(keys[grid_i]); changed = true
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_RIGHT: grid_i = (grid_i + 1) % n
			JOY_BUTTON_DPAD_LEFT: grid_i = (grid_i - 1 + n) % n
			JOY_BUTTON_DPAD_DOWN: grid_i = mini(n - 1, grid_i + 7)
			JOY_BUTTON_DPAD_UP: grid_i = maxi(0, grid_i - 7)
			JOY_BUTTON_A: _press_grid(keys[grid_i])
			JOY_BUTTON_B: name_str = name_str.substr(0, maxi(0, name_str.length() - 1))
			JOY_BUTTON_START:
				_sign()
				return
		changed = true
	if changed and stage == "name":
		get_viewport().set_input_as_handled()
		_build_naming()

func _press_grid(k: String) -> void:
	if k == "Sign":
		_sign()
	elif k == "⌫":
		name_str = name_str.substr(0, maxi(0, name_str.length() - 1))
		Sfx.play("cancel")
	elif name_str.length() < 7:
		name_str += k
		Sfx.play("blip")
		if name_str.length() == 7:
			grid_i = _keys().size() - 1

func _sign() -> void:
	if stage != "name":
		return
	Sfx.play("select")
	stage = "done"
	chosen.emit("new", name_str if name_str != "" else "ARIN", slot_i + 1)

func _name_blink() -> void:
	if int(t * 3.0) != int((t - get_process_delta_time()) * 3.0):
		_build_naming()

func _clear_ui() -> void:
	for c in ui.get_children():
		c.queue_free()

func _diamond(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)

func _odiamond(c: Vector2, sz: float, col: Color) -> void:
	overlay.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -sz), c + Vector2(sz, 0), c + Vector2(0, sz), c + Vector2(-sz, 0)]), col)

func _draw() -> void:
	for s in stars:
		var a := 0.4 + 0.6 * absf(sin(t * (0.5 + s.z) + s.z * 10.0))
		draw_rect(Rect2(s.x, s.y, 1, 1), Color(1, 1, 1, a))
	var hz := 168.0
	var pts := PackedVector2Array([Vector2(250, hz), Vector2(285, hz - 14), Vector2(320, hz - 20), Vector2(350, hz - 26), Vector2(372, hz - 18), Vector2(410, hz - 10), Vector2(440, hz)])
	draw_colored_polygon(pts, Color("0d0a1c"))
	draw_rect(Rect2(355, hz - 58, 8, 34), Color("0d0a1c"))
	draw_rect(Rect2(352, hz - 64, 14, 8), Color("0d0a1c"))
	var pulse := 0.5 + 0.5 * sin(t * 2.0)
	draw_circle(Vector2(359, hz - 60), 3.0 + pulse * 2.0, Color(0.7, 0.3, 1.0, 0.3 + pulse * 0.3))
	for i in 8:
		var y := hz + 8 + i * 9
		var w := 30.0 - i * 2.5 + sin(t * 2.0 + i) * 4.0
		draw_rect(Rect2(120 - w / 2, y, w, 2), Color(0.9, 0.9, 1.0, 0.25 - i * 0.025))
	draw_circle(Vector2(120, 48), 14, Color(0.95, 0.95, 1.0, 0.9))
	draw_circle(Vector2(126, 44), 12, Color("070818"))

func _draw_overlay() -> void:
	match stage:
		"menu":
			var y0 := 128.0
			overlay.draw_rect(Rect2(150, y0 - 8, 180, options.size() * 18 + 12), Color(0.04, 0.03, 0.07, 0.82))
			overlay.draw_line(Vector2(158, y0 - 8), Vector2(322, y0 - 8), Game.C_BORDER, 1.0)
			overlay.draw_line(Vector2(158, y0 + options.size() * 18 + 4), Vector2(322, y0 + options.size() * 18 + 4), Game.C_BORDER, 1.0)
			var cy := y0 + cursor * 18 + 7
			for i in 5:
				overlay.draw_circle(Vector2(166, cy), 9.0 - i * 1.5, Color(1, 0.7, 0.3, 0.06))
			_odiamond(Vector2(166, cy), 3.5 + sin(t * 6.0) * 0.6, Game.C_GOLD)
		"slots":
			overlay.draw_rect(Rect2(0, 0, 480, 270), Color(0.02, 0.015, 0.04, 0.7))
			for i in Game.SLOTS:
				var r := Rect2(70, 64 + i * 52, 340, 44)
				var on := i == slot_i
				overlay.draw_rect(r, Color(0.08, 0.06, 0.11, 0.95) if Game.slot_used(i + 1) else Color(0.05, 0.04, 0.07, 0.9))
				overlay.draw_rect(r, Game.C_GOLD if on else Color(Game.C_BORDER.r, Game.C_BORDER.g, Game.C_BORDER.b, 0.4), false, 1.0)
				# little book spine
				overlay.draw_rect(Rect2(r.position + Vector2(8, 8), Vector2(20, 28)), Color("6a3420") if Game.slot_used(i + 1) else Color("2a2030"))
				overlay.draw_rect(Rect2(r.position + Vector2(10, 8), Vector2(2, 28)), Color("8a5430") if Game.slot_used(i + 1) else Color("3a3040"))
				if on:
					_odiamond(r.position + Vector2(-10, 22), 4.0, Game.C_GOLD)
		"name":
			overlay.draw_rect(Rect2(0, 0, 480, 270), Color(0.02, 0.015, 0.04, 0.75))
			var page := Rect2(110, 30, 260, 214)
			overlay.draw_rect(page.grow(3), Color("4a2c1a"))
			overlay.draw_rect(page, Game.C_PAGE)
			# signature line
			overlay.draw_line(Vector2(140, 92), Vector2(340, 92), Color(0.3, 0.2, 0.1, 0.6), 1.0)

# ------------------------------------------------------------------ main menu
func _open_menu() -> void:
	stage = "menu"
	options = []
	if Game.has_save():
		options.append(["continue", "Continue the journey"])
		options.append(["load", "Open a journal"])
	options.append(["new", "Begin a new journey"])
	options.append(["speed", ""])
	if not OS.has_feature("web"):   # a browser tab can't be closed by the game
		options.append(["quit", "Leave"])
	cursor = 0
	_build_menu()

func _build_menu() -> void:
	_clear_ui()
	for i in options.size():
		var txt: String = options[i][1]
		if options[i][0] == "speed":
			txt = "Text speed:  %s" % ["Slow", "Medium", "Fast"][int(Game.options["text_speed"])]
		var l := Game.make_label(txt, 11, Game.C_GOLD if i == cursor else Game.C_DIM, false)
		l.position = Vector2(178, 128 + i * 18)
		ui.add_child(l)
	if options[cursor][0] == "continue":
		var s := Game.slot_summary(Game.most_recent_slot())
		var l2 := Game.make_label(s, 8, Game.C_TEXT, false)
		l2.position = Vector2(0, 236)
		l2.size = Vector2(480, 12)
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ui.add_child(l2)

func _menu_input() -> void:
	if Input.is_action_just_pressed("ui_u"):
		cursor = (cursor - 1 + options.size()) % options.size(); Sfx.play("blip"); _build_menu()
	elif Input.is_action_just_pressed("ui_d"):
		cursor = (cursor + 1) % options.size(); Sfx.play("blip"); _build_menu()
	elif Input.is_action_just_pressed("ui_ok"):
		var o: String = options[cursor][0]
		Sfx.play("select")
		match o:
			"continue":
				chosen.emit("continue", "", Game.most_recent_slot())
			"load":
				_open_slots("load")
			"new":
				_open_slots("new")
			"speed":
				Game.options["text_speed"] = (int(Game.options["text_speed"]) + 1) % 3
				Game.save_options()
				_build_menu()
			"quit":
				get_tree().quit()
	elif Input.is_action_just_pressed("ui_back"):
		Sfx.play("cancel")
		_clear_ui()
		stage = "intro"
		t = 0.5

# ------------------------------------------------------------------ journal slots
func _open_slots(mode: String) -> void:
	slot_mode = mode
	stage = "slots"
	confirm_overwrite = false
	slot_i = 0
	if mode == "new":
		for s in range(1, Game.SLOTS + 1):
			if not Game.slot_used(s):
				slot_i = s - 1
				break
	else:
		slot_i = maxi(0, Game.most_recent_slot() - 1)
	_build_slots()

func _build_slots() -> void:
	_clear_ui()
	var head := Game.make_label("Choose a journal to open" if slot_mode == "load" else "Choose a journal for your new journey", 12, Game.C_GOLD, false)
	head.position = Vector2(0, 34)
	head.size = Vector2(480, 16)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(head)
	for i in Game.SLOTS:
		var s := i + 1
		var used := Game.slot_used(s)
		var a := Game.make_label("Journal %d" % s, 11, Game.C_GOLD if i == slot_i else Game.C_TEXT, false)
		a.position = Vector2(110, 68 + i * 52)
		ui.add_child(a)
		var b := Game.make_label(Game.slot_summary(s) if used else "— blank pages —", 9, Game.C_TEXT if used else Game.C_DIM, false)
		b.position = Vector2(110, 86 + i * 52)
		ui.add_child(b)
	var msg := "Z  open      X  back"
	if confirm_overwrite:
		msg = "Journal %d holds another journey.  Z  write over it      X  keep it" % (slot_i + 1)
	elif slot_mode == "load" and not Game.slot_used(slot_i + 1):
		msg = "These pages are blank.      X  back"
	var h := Game.make_label(msg, 9, Color(1, 0.6, 0.5) if confirm_overwrite else Game.C_DIM, false)
	h.position = Vector2(0, 228)
	h.size = Vector2(480, 12)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(h)

func _slots_input() -> void:
	if confirm_overwrite:
		if Input.is_action_just_pressed("ui_ok"):
			Sfx.play("select")
			_open_naming()
		elif Input.is_action_just_pressed("ui_back"):
			Sfx.play("cancel")
			confirm_overwrite = false
			_build_slots()
		return
	if Input.is_action_just_pressed("ui_u"):
		slot_i = (slot_i - 1 + Game.SLOTS) % Game.SLOTS; Sfx.play("blip"); _build_slots()
	elif Input.is_action_just_pressed("ui_d"):
		slot_i = (slot_i + 1) % Game.SLOTS; Sfx.play("blip"); _build_slots()
	elif Input.is_action_just_pressed("ui_back"):
		Sfx.play("cancel")
		_open_menu()
	elif Input.is_action_just_pressed("ui_ok"):
		var used := Game.slot_used(slot_i + 1)
		if slot_mode == "load":
			if used:
				Sfx.play("select")
				chosen.emit("continue", "", slot_i + 1)
			else:
				Sfx.play("cancel")
		else:
			Sfx.play("select")
			if used:
				confirm_overwrite = true
				_build_slots()
			else:
				_open_naming()

# ------------------------------------------------------------------ name signing
func _open_naming() -> void:
	stage = "name"
	name_str = ""
	grid_i = 0
	_build_naming()

func _keys() -> Array:
	var k := []
	for c in LETTERS:
		k.append(c)
	k.append("⌫")
	k.append("Sign")
	return k

func _build_naming() -> void:
	_clear_ui()
	var ink := Game.C_INK
	var h := Game.make_label("Sign the first page of Journal %d" % (slot_i + 1), 11, Color("5a2a14"), false)
	h.position = Vector2(110, 40)
	h.size = Vector2(260, 14)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(h)
	h.size = Vector2(260, 14)  # after add_child (Godot 4.7 label sizing)
	var shown := name_str
	if int(t * 3.0) % 2 == 0 and name_str.length() < 7:
		shown += "|"
	var nm := Game.make_label(shown, 18, Color("2a2a5a"), false)
	nm.position = Vector2(110, 66)
	nm.size = Vector2(260, 24)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(nm)
	nm.size = Vector2(260, 24)  # after add_child (Godot 4.7 label sizing)
	var keys := _keys()
	for i in keys.size():
		var col := i % 7
		var rowi := i / 7
		var l := Game.make_label(keys[i], 11, Color("a02010") if i == grid_i else ink, false)
		l.position = Vector2(132 + col * 32, 104 + rowi * 22)
		l.size = Vector2(28, 14)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i == grid_i:
			l.add_theme_font_size_override("font_size", 13)
		ui.add_child(l)
	var help := Game.make_label("Type your name  ·  Enter signs  ·  Backspace erases", 8, Color("6a5a40"), false)
	help.position = Vector2(110, 226)
	help.size = Vector2(260, 12)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(help)
	help.size = Vector2(260, 12)  # after add_child (Godot 4.7 label sizing)
