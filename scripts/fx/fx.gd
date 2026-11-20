class_name FX
extends RefCounted
## Static helpers for juicy effects.

static var _light_tex: Texture2D
static var _dot_tex: Texture2D
static var _shadow_tex: Texture2D
static var _sword_tex: Texture2D
static var _shader: Shader
static var _shader_unshaded: Shader
static var _orb_tex: Texture2D

static func light_texture() -> Texture2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.5, Color(1, 1, 1, 0.45))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(1.0, 0.5)
		gt.width = 128; gt.height = 128
		_light_tex = gt
	return _light_tex

static func dot_texture() -> Texture2D:
	if _dot_tex == null:
		var im := Image.create(4, 4, false, Image.FORMAT_RGBA8)
		im.fill(Color.WHITE)
		_dot_tex = ImageTexture.create_from_image(im)
	return _dot_tex

static func orb_texture() -> Texture2D:
	if _orb_tex == null:
		var im := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		for y in 8:
			for x in 8:
				var d := Vector2(x - 3.5, y - 3.5).length()
				if d < 3.6:
					im.set_pixel(x, y, Color(1, 1, 1, 1) if d < 2.0 else Color(1, 1, 1, 0.6))
		_orb_tex = ImageTexture.create_from_image(im)
	return _orb_tex

static func shadow_texture() -> Texture2D:
	if _shadow_tex == null:
		var im := Image.create(14, 6, false, Image.FORMAT_RGBA8)
		for y in 6:
			for x in 14:
				var d := Vector2((x - 6.5) / 7.0, (y - 2.5) / 3.0).length()
				if d < 1.0:
					im.set_pixel(x, y, Color(0, 0, 0, 0.35))
		_shadow_tex = ImageTexture.create_from_image(im)
	return _shadow_tex

static func sword_texture() -> Texture2D:
	if _sword_tex == null:
		# a 16x5 pixel sword pointing right, hilt at left
		var im := Image.create(16, 5, false, Image.FORMAT_RGBA8)
		var blade := Color("e8f0f8"); var edge := Color("a8b8c8"); var hilt := Color("8a5a2a"); var guard := Color("e0b040")
		for x in range(0, 4):
			im.set_pixel(x, 2, hilt)
		for y in range(0, 5):
			im.set_pixel(4, y, guard)
		for x in range(5, 15):
			im.set_pixel(x, 1, edge); im.set_pixel(x, 2, blade); im.set_pixel(x, 3, edge)
		im.set_pixel(15, 2, blade)
		_sword_tex = ImageTexture.create_from_image(im)
	return _sword_tex

static func actor_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = """
shader_type canvas_item;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float shadow : hint_range(0.0, 1.0) = 0.0;
uniform vec4 tint : source_color = vec4(0.42, 0.18, 0.62, 1.0);
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
varying vec4 vcol;
void vertex(){ vcol = COLOR; }
void fragment(){
  vec4 c = texture(TEXTURE, UV);
  vec2 px = TEXTURE_PIXEL_SIZE;
  float lum = dot(c.rgb, vec3(0.3, 0.59, 0.11));
  vec3 s = tint.rgb * (0.25 + lum * 1.1);
  // the brightest pixels smoulder faintly, like embers behind the eyes
  if (lum > 0.9) { s = mix(s, vec3(0.85, 0.55 + 0.1*sin(TIME*5.0), 1.0), 0.45); }
  vec3 col = mix(c.rgb, s, shadow);
  float na = texture(TEXTURE, UV + vec2(px.x, 0.0)).a + texture(TEXTURE, UV - vec2(px.x, 0.0)).a
           + texture(TEXTURE, UV + vec2(0.0, px.y)).a + texture(TEXTURE, UV - vec2(0.0, px.y)).a;
  vec4 outc = vec4(col, c.a);
  if (c.a < 0.1 && na > 0.0 && shadow > 0.5) {
    outc = vec4(tint.rgb * 1.5 + vec3(0.15) * sin(TIME * 4.0 + UV.y * 20.0), 0.55);
  }
  outc.rgb = mix(outc.rgb, flash_color.rgb, flash);
  COLOR = outc * vcol;
}
"""
	return _shader

static func make_actor_material(shadowed := false, tint := Color(0.42, 0.18, 0.62), unshaded := false) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	if unshaded:
		if _shader_unshaded == null:
			_shader_unshaded = Shader.new()
			_shader_unshaded.code = actor_shader().code.replace("shader_type canvas_item;", "shader_type canvas_item;\nrender_mode unshaded;")
		m.shader = _shader_unshaded
	else:
		m.shader = actor_shader()
	m.set_shader_parameter("shadow", 1.0 if shadowed else 0.0)
	m.set_shader_parameter("tint", tint)
	return m

static func fire_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.amount = 10
	p.lifetime = 0.6
	p.texture = dot_texture()
	p.scale_amount_min = 0.25; p.scale_amount_max = 0.6
	p.direction = Vector2(0, -1); p.spread = 25
	p.gravity = Vector2(0, -30)
	p.initial_velocity_min = 6; p.initial_velocity_max = 16
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 2.0
	var g := Gradient.new()
	g.set_color(0, Color(1, 0.95, 0.5, 1)); g.set_color(1, Color(0.9, 0.2, 0.1, 0))
	p.color_ramp = g
	return p

static func burst(parent: Node, pos: Vector2, color: Color, amount := 12, speed := 70.0, life := 0.45, size := 0.6) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.texture = dot_texture()
	p.scale_amount_min = size * 0.5; p.scale_amount_max = size
	p.spread = 180
	p.gravity = Vector2(0, 60)
	p.initial_velocity_min = speed * 0.4; p.initial_velocity_max = speed
	p.damping_min = 40; p.damping_max = 80
	var g := Gradient.new()
	g.set_color(0, color); g.set_color(1, Color(color.r, color.g, color.b, 0))
	p.color_ramp = g
	p.position = pos
	p.z_index = 60
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)

static func dust(parent: Node, pos: Vector2) -> void:
	burst(parent, pos, Color(0.95, 0.9, 0.75, 0.7), 5, 25.0, 0.35, 0.5)

static func damage_number(parent: Node, pos: Vector2, amount: int, crit := false, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = str(amount) + ("!" if crit else "")
	l.add_theme_font_size_override("font_size", 13 if crit else 9)
	l.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if crit else color)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos + Vector2(-10 + randf_range(-4, 4), -26)
	l.z_index = 80
	l.size = Vector2(20, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.pivot_offset = Vector2(10, 6)
	parent.add_child(l)
	l.scale = Vector2(1.6, 1.6) if crit else Vector2(1.2, 1.2)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "scale", Vector2.ONE, 0.15)
	tw.tween_property(l, "position:y", l.position.y - 16, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)

static func float_text(parent: Node, pos: Vector2, text: String, color := Color.WHITE) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 3)
	l.z_index = 80
	l.position = pos + Vector2(-30, -30)
	l.size = Vector2(60, 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 14, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.4).set_delay(0.6)
	tw.tween_callback(l.queue_free)

static func afterimage(parent: Node, sprite: Sprite2D, color := Color(0.5, 0.8, 1.0, 0.6)) -> void:
	var s := Sprite2D.new()
	s.texture = sprite.texture
	s.hframes = sprite.hframes
	s.vframes = sprite.vframes
	s.frame = sprite.frame
	s.flip_h = sprite.flip_h
	s.global_position = sprite.global_position
	s.offset = sprite.offset
	s.scale = sprite.global_scale
	s.modulate = color
	s.z_index = 5
	parent.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)

static func slash(parent: Node, pos: Vector2, angle: float, radius := 18.0, sweep := 2.4, color := Color(1, 1, 1, 0.9), width := 6.0, dur := 0.16) -> void:
	var a := SlashArc.new()
	a.position = pos
	a.rotation = angle
	a.radius = radius
	a.sweep = sweep
	a.color = color
	a.width = width
	a.duration = dur
	a.z_index = 40
	parent.add_child(a)

static func ring(parent: Node, pos: Vector2, max_radius: float, color: Color, dur := 0.35, width := 3.0) -> void:
	var r := RingFX.new()
	r.position = pos
	r.max_radius = max_radius
	r.color = color
	r.duration = dur
	r.width = width
	r.z_index = 40
	parent.add_child(r)

static func telegraph(parent: Node, pos: Vector2, radius: float, dur: float, color := Color(1, 0.2, 0.3, 0.5)) -> void:
	var t := TelegraphFX.new()
	t.position = pos
	t.radius = radius
	t.duration = dur
	t.color = color
	t.z_index = -5
	parent.add_child(t)
