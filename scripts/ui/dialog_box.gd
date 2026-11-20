class_name DialogBox
extends Control
## "Lantern & Ink" dialogue: a translucent ink scroll at the bottom, gold speaker caption,
## typewriter text, pulsing lantern-diamond to advance, choices listed inline on the right.

signal advanced

var label: Label
var speaker_label: Label
var choice_labels: Array = []
var choices: Array = []
var choice_i := 0
var typing := false
var waiting := false
var choosing := false
var t := 0.0
var chars := 0.0
var open_count := 0
var blip_acc := 0
var speaker := ""
var appear := 0.0

const R := Rect2(20, 200, 440, 62)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker_label = Game.make_label("", 9, Game.C_GOLD)
	speaker_label.position = R.position + Vector2(14, -14)
	add_child(speaker_label)
	label = Game.make_label("", 11)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = R.position + Vector2(14, 8)
	label.size = Vector2(R.size.x - 28, R.size.y - 14)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_constant_override("line_spacing", 1)
	add_child(label)
	visible = false

func is_open() -> bool:
	return visible

func _draw() -> void:
	var a := clampf(appear, 0.0, 1.0)
	var r := R
	r.position.y += (1.0 - a) * 10.0
	# soft glow behind the scroll
	draw_rect(r.grow(6), Color(0, 0, 0, 0.35 * a))
	draw_rect(r, Color(0.06, 0.05, 0.09, 0.93 * a))
	# gold hairlines top and bottom, with diamond terminals
	var g := Color(Game.C_BORDER.r, Game.C_BORDER.g, Game.C_BORDER.b, a)
	draw_line(r.position + Vector2(8, 0), r.position + Vector2(r.size.x - 8, 0), g, 1.0)
	draw_line(r.position + Vector2(8, r.size.y), r.position + Vector2(r.size.x - 8, r.size.y), g, 1.0)
	for p in [r.position + Vector2(6, 0), r.position + Vector2(r.size.x - 6, 0), r.position + Vector2(6, r.size.y), r.position + Vector2(r.size.x - 6, r.size.y)]:
		_diamond(p, 3.0, g)
	# speaker caption tab
	if speaker != "":
		var w := speaker_label.get_minimum_size().x + 20
		var cr := Rect2(r.position + Vector2(6, -16), Vector2(w, 15))
		draw_rect(cr, Color(0.06, 0.05, 0.09, 0.93 * a))
		draw_line(cr.position, cr.position + Vector2(cr.size.x, 0), g, 1.0)
		draw_line(cr.position, cr.position + Vector2(0, cr.size.y), g, 1.0)
		draw_line(cr.position + Vector2(cr.size.x, 0), cr.position + cr.size, g, 1.0)
	# advance marker
	if waiting and not typing and not choosing:
		var pulse := 0.6 + 0.4 * sin(t * 6.0)
		_diamond(r.end - Vector2(14, 10) + Vector2(0, sin(t * 4.0) * 1.5), 3.5, Color(1.0, 0.82, 0.4, pulse * a))
	# choice list (drawn as a stack of lantern tags above the right edge)
	if choosing:
		var h := choices.size() * 15 + 8
		var cr2 := Rect2(r.end.x - 120, r.position.y - h - 6, 120, h)
		draw_rect(cr2, Color(0.06, 0.05, 0.09, 0.95))
		draw_rect(cr2, g, false, 1.0)
		var sel_y := cr2.position.y + 4 + choice_i * 15
		draw_rect(Rect2(cr2.position.x + 2, sel_y, cr2.size.x - 4, 14), Color(0.78, 0.6, 0.25, 0.25 + 0.1 * sin(t * 6.0)))
		_diamond(Vector2(cr2.position.x + 10, sel_y + 7), 3.0, Game.C_GOLD)

func _diamond(c: Vector2, s: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s, 0), c + Vector2(0, s), c + Vector2(-s, 0)]), col)

func _process(delta: float) -> void:
	if not visible:
		return
	t += delta
	appear = minf(1.0, appear + delta * 8.0)
	label.modulate.a = appear
	speaker_label.modulate.a = appear
	queue_redraw()
	if typing:
		var spd: float = [28.0, 55.0, 140.0][int(Game.options["text_speed"])]
		chars += delta * spd
		var n := int(chars)
		if n != label.visible_characters:
			label.visible_characters = n
			blip_acc += 1
			if blip_acc % 3 == 0:
				Sfx.play("text", 1.0, -10.0)
		if n >= label.get_total_character_count():
			typing = false
			label.visible_characters = -1
		elif Input.is_action_just_pressed("ui_ok") and chars > 2.0:
			typing = false
			label.visible_characters = -1
			return
	if choosing:
		var n := choices.size()
		if Input.is_action_just_pressed("ui_u") or Input.is_action_just_pressed("ui_l"):
			choice_i = (choice_i - 1 + n) % n
			Sfx.play("blip")
			_refresh_choice()
		elif Input.is_action_just_pressed("ui_d") or Input.is_action_just_pressed("ui_r"):
			choice_i = (choice_i + 1) % n
			Sfx.play("blip")
			_refresh_choice()
		elif Input.is_action_just_pressed("ui_ok"):
			Sfx.play("select")
			choosing = false
			advanced.emit()
		elif Input.is_action_just_pressed("ui_back"):
			Sfx.play("cancel")
			choice_i = n - 1
			choosing = false
			advanced.emit()
		return
	if waiting and not typing and Input.is_action_just_pressed("ui_ok"):
		waiting = false
		Sfx.play("blip", 1.2, -6.0)
		advanced.emit()

func _set_line(line: String) -> void:
	speaker = ""
	var txt := line
	var idx := line.find(": ")
	if idx > 0 and idx < 16 and line.substr(0, idx) == line.substr(0, idx).to_upper():
		speaker = line.substr(0, idx)
		txt = line.substr(idx + 2)
	speaker_label.text = speaker
	label.text = txt
	label.visible_characters = 0
	chars = 0.0
	typing = true

func _open() -> void:
	open_count += 1
	if not visible:
		appear = 0.0
	visible = true
	get_tree().paused = true

func _close() -> void:
	open_count -= 1
	if open_count <= 0:
		open_count = 0
		visible = false
		if Game.main and not Game.main.menu_open():
			get_tree().paused = false
		var p = Game.main.area.player if Game.main and Game.main.area else null
		if p:
			p.interact_lock = 0.3

func say(lines: Array) -> void:
	_open()
	for line in lines:
		_set_line(str(line).replace("{name}", str(Game.data.get("name", "ARIN"))))
		waiting = true
		await advanced
	_close()

func choose(question: String, options: Array) -> int:
	_open()
	_set_line(question)
	while typing:
		await get_tree().process_frame
	for c in choice_labels:
		c.queue_free()
	choice_labels.clear()
	choices = options
	var h := options.size() * 15 + 8
	for i in options.size():
		var l := Game.make_label(str(options[i]), 10)
		l.position = Vector2(R.end.x - 120 + 20, R.position.y - h - 6 + 4 + i * 15)
		add_child(l)
		choice_labels.append(l)
	choice_i = 0
	_refresh_choice()
	choosing = true
	await advanced
	for c in choice_labels:
		c.queue_free()
	choice_labels.clear()
	_close()
	return choice_i

func ask(question: String) -> bool:
	var r := await choose(question, ["Yes", "No"])
	return r == 0

func _refresh_choice() -> void:
	for i in choice_labels.size():
		(choice_labels[i] as Label).add_theme_color_override("font_color", Game.C_GOLD if i == choice_i else Game.C_DIM)
