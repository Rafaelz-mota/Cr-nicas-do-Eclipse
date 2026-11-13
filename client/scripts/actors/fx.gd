class_name Fx
extends RefCounted
## Efeitos visuais leves (texto flutuante, projétil, partículas de impacto).
## Pensados para rodar em celulares Android (poucos nós, CPU particles).


static func floating_text(parent: Node, world_pos: Vector3, text: String, color: Color, font_size: int = 56) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var l := Label3D.new()
	l.text = text
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = font_size
	l.pixel_size = 0.008
	l.no_depth_test = true
	l.outline_size = 10
	parent.add_child(l)
	l.global_position = world_pos
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.4, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(l.queue_free)


static func bolt(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.15
	s.height = 0.3
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	parent.add_child(m)
	m.global_position = from
	var tw := m.create_tween()
	tw.tween_property(m, "global_position", to, 0.15)
	tw.tween_callback(m.queue_free)


static func hit_burst(parent: Node, world_pos: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var p := CPUParticles3D.new()
	var s := SphereMesh.new()
	s.radius = 0.06
	s.height = 0.12
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s.material = mat
	p.mesh = s
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 10
	p.lifetime = 0.4
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -9.0, 0)
	parent.add_child(p)
	p.global_position = world_pos
	p.emitting = true
	p.get_tree().create_timer(1.0).timeout.connect(p.queue_free)
