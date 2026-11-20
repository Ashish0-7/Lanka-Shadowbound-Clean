class_name Hud
extends Control
## Action-RPG HUD: portrait + bars, minimap, skill hotbar, boss bar, banner, toasts.

var area: GameArea
var t := 0.0
var mini_rect: TextureRect
var mini_atlas: AtlasTexture
var lv_label: Label
var hp_label: Label
var coin_label: Label
var banner: PanelContainer
var banner_label: Label
var toast_box: VBoxContainer
var boss_name := ""
var boss_ratio := 1.0
var boss_shown := 0.0
var boss_label: Label
var hp_disp := 1.0
var hp_lag := 1.0
var key_labels: Array = []
var portrait: TextureRect

const SLOT_ICONS := {"attack": "", "whirl": "seashell_spiral", "bolt": "gold_coin", "radiant": "lighthouse_top"}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait = TextureRect.new()
	portrait.texture = Game.tex("hero")
	portrait.position = Vector2(8, 7)
	portrait.size = Vector2(22, 22)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(portrait)
	lv_label = Game.make_label("Lv1", 8, Color.WHITE)
	lv_label.position = Vector2(9, 28)
	add_child(lv_label)
	hp_label = Game.make_label("", 7, Color.WHITE)
	hp_label.position = Vector2(36, 3)
	add_child(hp_label)
	# minimap
	mini_atlas = AtlasTexture.new()
	mini_rect = TextureRect.new()
	mini_rect.texture = mini_atlas
	mini_rect.position = Vector2(480 - 90, 6)
	mini_rect.size = Vector2(84, 60)
	mini_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mini_rect.stretch_mode = TextureRect.STRETCH_SCALE
	mini_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(mini_rect)
	coin_label = Game.make_label("0", 9, Color(1, 0.9, 0.4))
	coin_label.position = Vector2(480 - 74, 68)
	add_child(coin_label)
	var coin_icon := TextureRect.new()
	coin_icon.texture = Game.tex("gold_coin")
	coin_icon.position = Vector2(480 - 90, 68)
	coin_icon.size = Vector2(12, 12)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(coin_icon)
	# banner (location sign)
	banner = Game.make_box()
	banner.position = Vector2(8, -60)
	add_child(banner)
	banner_label = Game.make_label("", 11, Game.C_GOLD)
	banner.add_child(banner_label)
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(140, 52)
	toast_box.size = Vector2(200, 60)
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_child(toast_box)
	boss_label = Game.make_label("", 9, Color(1, 0.85, 0.9))
	boss_label.position = Vector2(150, 4)
	boss_label.size = Vector2(180, 12)
	boss_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_label.visible = false
	add_child(boss_label)
	for k in ["X", "Q", "E", "Tab"]:
		var l := Game.make_label(k, 7, Color.WHITE)
		add_child(l)
		key_labels.append(l)
	Game.toast.connect(toast)
	Game.stats_changed.connect(queue_redraw)

func set_area(a: GameArea) -> void:
	area = a
	mini_atlas.atlas = a.mini_tex

func _process(delta: float) -> void:
	t += delta
	var d := Game.data
	var ratio := float(d["hp"]) / maxf(1.0, float(d["max_hp"]))
	hp_disp = lerpf(hp_disp, ratio, delta * 12.0)
	if hp_lag > hp_disp:
		hp_lag = maxf(hp_disp, hp_lag - delta * 0.4)
	else:
		hp_lag = hp_disp
	lv_label.text = "Lv%d" % d["level"]
	hp_label.text = "%d/%d" % [d["hp"], d["max_hp"]]
	coin_label.text = str(d["coins"])
	if area and area.player and is_instance_valid(area.player):
		var c := area.cell_of(area.player.global_position)
		var vw := 42; var vh := 30
		var rx := clampi(c.x - vw / 2, 0, maxi(0, area.W - vw))
		var ry := clampi(c.y - vh / 2, 0, maxi(0, area.H - vh))
		mini_atlas.region = Rect2(rx, ry, mini(vw, area.W), mini(vh, area.H))
		set_meta("pdot", Vector2(c.x - rx, c.y - ry) / Vector2(mini(vw, area.W), mini(vh, area.H)))
	boss_shown = move_toward(boss_shown, 1.0 if boss_name != "" else 0.0, delta * 3.0)
	boss_label.visible = boss_shown > 0.5
	queue_redraw()

func _bar(pos: Vector2, w: float, h: float, ratio: float, col: Color, lag := -1.0) -> void:
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0.08, 0.06, 0.12, 0.95))
	draw_rect(Rect2(pos, Vector2(w, h)), Color(0.2, 0.18, 0.26))
	if lag >= 0.0:
		draw_rect(Rect2(pos, Vector2(w * clampf(lag, 0, 1), h)), Color(1, 1, 1, 0.8))
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0, 1), h)), col)
	draw_rect(Rect2(pos, Vector2(w * clampf(ratio, 0, 1), 1)), col.lightened(0.4))

func _draw() -> void:
	var d := Game.data
	# portrait frame
	draw_rect(Rect2(5, 5, 27, 33), Color(0.08, 0.06, 0.12, 0.85))
	draw_rect(Rect2(5, 5, 27, 33), Color(0.85, 0.75, 0.45), false, 1.0)
	var hr := hp_disp
	var hc := Color(0.35, 0.85, 0.4) if hr > 0.5 else (Color(0.95, 0.8, 0.2) if hr > 0.2 else Color(0.95, 0.25, 0.2))
	if hr <= 0.2 and int(t * 4.0) % 2 == 0:
		hc = hc.lightened(0.3)
	_bar(Vector2(36, 13), 110, 7, hr, hc, hp_lag)
	_bar(Vector2(36, 23), 80, 4, float(d["mp"]) / maxf(1.0, float(d["max_mp"])), Color(0.35, 0.6, 1.0))
	_bar(Vector2(36, 30), 80, 2, float(d["xp"]) / maxf(1.0, float(Game.xp_to_next())), Color(1.0, 0.85, 0.3))
	# shards
	var sx := 122.0
	for s in ["tide_shard", "grove_shard", "ember_shard"]:
		var col: Color = Game.KEY_ITEMS[s]["tint"]
		var have := Game.has_key_item(s)
		var pts := PackedVector2Array([Vector2(sx, 22), Vector2(sx + 4, 26), Vector2(sx, 31), Vector2(sx - 4, 26)])
		draw_colored_polygon(pts, col if have else Color(0.2, 0.2, 0.25, 0.8))
		if have:
			draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1, 1, 1, 0.5 + 0.5 * sin(t * 3.0)), 1.0)
		sx += 10
	# minimap frame + player dot
	var mr := Rect2(mini_rect.position, mini_rect.size)
	draw_rect(mr.grow(2), Color(0.08, 0.06, 0.12, 0.9))
	draw_rect(mr, Color(0.03, 0.03, 0.07))
	if has_meta("pdot") and int(t * 4.0) % 2 == 0:
		var pd: Vector2 = get_meta("pdot")
		draw_rect(Rect2(mr.position + pd * mr.size - Vector2(1.5, 1.5), Vector2(3, 3)), Color(1, 0.3, 0.3))
	draw_rect(mr.grow(2), Color(0.85, 0.75, 0.45), false, 1.0)
	# hotbar
	var p = area.player if area and is_instance_valid(area.player) else null
	var slots := ["attack", "whirl", "bolt", "radiant"]
	var x0 := 240.0 - (slots.size() * 26.0) / 2.0
	for i in slots.size():
		var id: String = slots[i]
		var r := Rect2(x0 + i * 26, 270 - 30, 22, 22)
		draw_rect(r.grow(1), Color(0.08, 0.06, 0.12, 0.9))
		draw_rect(r, Color(0.2, 0.17, 0.28, 0.9))
		var learned: bool = id == "attack" or d["skills"].has(id)
		if id == "attack":
			draw_set_transform(r.get_center(), -PI / 4, Vector2(1, 1))
			draw_texture(FX.sword_texture(), Vector2(-8, -2.5))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		elif learned:
			draw_texture_rect(Game.tex(SLOT_ICONS[id]), r.grow(-3), false)
			var cd: float = p.cooldowns[id] if p else 0.0
			var full: float = Game.SKILLS[id]["cd"]
			if cd > 0.0:
				var k := cd / full
				draw_rect(Rect2(r.position + Vector2(0, r.size.y * (1.0 - k)), Vector2(r.size.x, r.size.y * k)), Color(0, 0, 0, 0.65))
			elif int(d["mp"]) < int(Game.SKILLS[id]["cost"]):
				draw_rect(r, Color(0.1, 0.1, 0.4, 0.55))
		else:
			draw_rect(r, Color(0, 0, 0, 0.5))
			draw_string(ThemeDB.fallback_font, r.position + Vector2(8, 15), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.6, 0.6, 0.7))
		draw_rect(r.grow(1), Color(0.85, 0.75, 0.45) if learned else Color(0.4, 0.4, 0.45), false, 1.0)
		var kl: Label = key_labels[i]
		kl.position = r.position + Vector2(1, -2)
	# boss bar
	if boss_shown > 0.01:
		var a := boss_shown
		var br := Rect2(160, 18, 160, 6)
		draw_rect(br.grow(2), Color(0.06, 0.03, 0.08, 0.9 * a))
		draw_rect(br, Color(0.25, 0.1, 0.2, a))
		draw_rect(Rect2(br.position, Vector2(br.size.x * boss_ratio, br.size.y)), Color(0.85, 0.2, 0.35, a))
		draw_rect(Rect2(br.position, Vector2(br.size.x * boss_ratio, 2)), Color(1, 0.5, 0.6, a))
		draw_rect(br.grow(2), Color(0.85, 0.75, 0.45, a), false, 1.0)

var _banner_tw: Tween
func show_banner(text: String) -> void:
	if _banner_tw:
		_banner_tw.kill()
	var tw := create_tween()
	_banner_tw = tw
	banner_label.text = "◆  %s  ◆" % text
	banner.reset_size()
	banner.position = Vector2(240 - banner.get_combined_minimum_size().x / 2.0, 40)
	banner.modulate.a = 0.0
	tw.tween_property(banner, "modulate:a", 1.0, 0.5)
	tw.parallel().tween_property(banner, "position:y", 34.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.0)
	tw.tween_property(banner, "modulate:a", 0.0, 0.7)

func toast(text: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(200, 16)
	toast_box.add_child(l)
	l.scale = Vector2(1.0, 1.0)
	var tw := l.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

func show_boss(name: String, ratio: float) -> void:
	boss_name = name
	boss_ratio = ratio
	boss_label.text = name

func hide_boss() -> void:
	boss_name = ""
