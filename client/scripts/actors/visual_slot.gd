class_name VisualSlot
extends Node3D
## Ponto único onde o modelo visual de um ator é plugado.
## Hoje: placeholder procedural. Amanhã: set_model(cena .glb/.tscn do modelo
## 3D anime) sem tocar em combate, equipamentos ou personagens.

var model_id: String = ""


func use_placeholder(color: Color, height: float = 1.8, radius: float = 0.4) -> void:
	clear()
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.height = height
	capsule.radius = radius
	body.mesh = capsule
	body.position.y = height * 0.5
	body.material_override = _material(color)
	add_child(body)
	# Marcador de frente (-Z), para enxergar a direção do ator.
	var nose := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(radius * 0.6, radius * 0.5, radius * 0.9)
	nose.mesh = box
	nose.position = Vector3(0, height * 0.7, -radius * 0.95)
	nose.material_override = _material(color.lightened(0.5))
	add_child(nose)


func set_model(scene: PackedScene, p_model_id: String = "") -> void:
	clear()
	model_id = p_model_id
	add_child(scene.instantiate())


func clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()


static func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.8
	return m
