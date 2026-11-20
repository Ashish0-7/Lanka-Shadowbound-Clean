class_name Projectile
extends Node2D

var area: GameArea
var friendly := false
var velocity := Vector2.ZERO
var damage := 5
var color := Color.WHITE
var radius := 4.0
var life := 2.6
var pierce := 0
var accel := 0.0
var homing := 0.0
var hit := {}
var spr: Sprite2D
var light: PointLight2D
var t := 0.0

func _ready() -> void:
	spr = Sprite2D.new()
	spr.texture = FX.orb_texture()
	spr.modulate = color
	spr.scale = Vector2.ONE * (radius / 3.0)
	add_child(spr)
	var core := Sprite2D.new()
	core.texture = FX.orb_texture()
	core.scale = Vector2.ONE * (radius / 6.0)
	add_child(core)
	light = PointLight2D.new()
	light.texture = FX.light_texture()
	light.texture_scale = 0.35 + radius * 0.05
	light.color = color
	light.energy = 0.9
	add_child(light)
	var trail := CPUParticles2D.new()
	trail.amount = 10
	trail.lifetime = 0.3
	trail.texture = FX.dot_texture()
	trail.scale_amount_min = 0.3; trail.scale_amount_max = 0.6
	trail.gravity = Vector2.ZERO
	trail.local_coords = false
	var g := Gradient.new()
	g.set_color(0, color); g.set_color(1, Color(color.r, color.g, color.b, 0))
	trail.color_ramp = g
	add_child(trail)

func _physics_process(delta: float) -> void:
	t += delta
	life -= delta
	if life <= 0.0:
		_pop()
		return
	if accel != 0.0:
		velocity += velocity.normalized() * accel * delta
	if homing > 0.0 and area.player and not friendly:
		var want := (area.player.global_position + Vector2(0, -6) - global_position).normalized() * velocity.length()
		velocity = velocity.lerp(want, homing * delta)
	position += velocity * delta
	spr.rotation += delta * 8.0
	spr.scale = Vector2.ONE * (radius / 3.0) * (1.0 + 0.15 * sin(t * 25.0))
	if area.is_solid_px(global_position + Vector2(0, 6)) and not area.gget(area.cell_of(global_position).x, area.cell_of(global_position).y).begins_with("water"):
		_pop()
		return
	if friendly:
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e) or e.dead or hit.has(e.get_instance_id()):
				continue
			if (e.global_position + Vector2(0, -6)).distance_to(global_position) < radius + e.radius:
				hit[e.get_instance_id()] = true
				var crit := randf() < 0.15
				e.take_hit(int(damage * (1.6 if crit else 1.0)), velocity.normalized(), 140.0, crit)
				Game.shake(1.5)
				pierce -= 1
				if pierce < 0:
					_pop()
					return
	else:
		var p := area.player
		if p and p.state != "dead" and (p.global_position + Vector2(0, -6)).distance_to(global_position) < radius + 4.0:
			if p.invuln <= 0.0:
				p.take_hit(damage, global_position - velocity.normalized() * 10.0, 110.0)
				_pop()

func _pop() -> void:
	FX.burst(area.fx, global_position, color, 8, 50.0, 0.3, 0.5)
	queue_free()
