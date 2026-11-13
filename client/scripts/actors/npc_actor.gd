class_name NpcActor
extends Node3D
## NPC que entrega missões (npcs.json). Interação tratada pelo mundo (main.gd).

var npc_id: String = ""
var def: Dictionary = {}
var visual: VisualSlot


func setup(p_def: Dictionary) -> void:
	def = p_def
	npc_id = def["id"]
	add_to_group("npcs")
	visual = VisualSlot.new()
	add_child(visual)
	visual.use_placeholder(Color(def.get("color", "#e0a458")), 1.8, 0.4)
	var label := Label3D.new()
	label.text = def["name"]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.font_size = 64
	label.outline_size = 8
	label.no_depth_test = true
	label.position.y = 2.4
	add_child(label)
	var pos: Array = def.get("position", [0, 0, 0])
	position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
