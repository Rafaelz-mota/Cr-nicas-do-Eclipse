class_name MonsterActor
extends CharacterBody3D
## Monstro genérico dirigido por dados (monsters.json). Novos monstros não
## exigem código novo: só uma entrada no JSON.

signal died(monster: MonsterActor, killer: Node3D)

const GRAVITY := 25.0

var def: Dictionary = {}
var data: GameDataStore
var combatant: Combatant
var visual: VisualSlot
var label: Label3D
var spawn_pos: Vector3
var target: PlayerActor = null
var last_attacker: Node3D = null
var attack_skill: Dictionary = {}
var rng := RandomNumberGenerator.new()
var _dead := false


func setup(p_def: Dictionary, p_data: GameDataStore, p_spawn: Vector3) -> void:
	def = p_def
	data = p_data
	spawn_pos = p_spawn
	rng.randomize()
	add_to_group("monsters")
	var ai: Dictionary = def["ai"]
	var scale_f: float = float(def.get("scale", 1.0))

	combatant = Combatant.new()
	combatant.setup(def["id"], def["name"], int(def["level"]), def["stats"], def.get("resistances", {}))
	attack_skill = {"id": "ataque_basico", "damage_type": "physical", "power": 1.0, "mana_cost": 0.0,
		"cooldown": float(ai["attack_cooldown"]), "level_required": 1, "range": float(ai["attack_range"])}

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.5 * scale_f
	shape.height = 1.4 * scale_f
	col.shape = shape
	col.position.y = 0.7 * scale_f
	add_child(col)

	visual = VisualSlot.new()
	add_child(visual)
	visual.use_placeholder(Color(def.get("color", "#cc4444")), 1.4 * scale_f, 0.5 * scale_f)

	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.font_size = 40
	label.outline_size = 8
	label.no_depth_test = true
	label.position.y = 1.9 * scale_f
	add_child(label)
	global_position = p_spawn
	_update_label()


func _update_label() -> void:
	label.text = "%s Nv%d\n%d/%d" % [combatant.display_name, combatant.level, int(ceil(combatant.hp)), int(combatant.get_stat("max_hp"))]


func _physics_process(delta: float) -> void:
	if _dead or combatant == null:
		return
	for ev in combatant.tick(delta, {}):
		if ev["type"] == "dot":
			Fx.floating_text(get_parent(), global_position + Vector3(0, 2.0, 0), str(ev["damage"]), Color("#ff8844"))
	if not combatant.is_alive():
		_die(last_attacker)
		return

	var ai: Dictionary = def["ai"]
	var speed: float = float(ai["move_speed"])
	var wish := Vector3.ZERO

	if target != null and (not is_instance_valid(target) or not target.combatant.is_alive()):
		target = null
	if target == null:
		target = _find_player(float(ai["aggro_range"]))

	if target != null:
		var from_spawn := global_position.distance_to(spawn_pos)
		if from_spawn > float(ai["leash_range"]):
			target = null  # desiste e volta
		else:
			var to_t := target.global_position - global_position
			to_t.y = 0.0
			var dist := to_t.length()
			rotation.y = atan2(-to_t.x, -to_t.z)
			if dist > float(ai["attack_range"]) * 0.9:
				wish = to_t.normalized() * speed
			elif combatant.can_use(attack_skill) == "":
				var r := combatant.use_skill(attack_skill, target.combatant, rng, data.balance)
				if r["ok"]:
					target.on_hit_taken(r, self)
	if target == null:
		var back := spawn_pos - global_position
		back.y = 0.0
		if back.length() > 0.6:
			wish = back.normalized() * speed
			rotation.y = atan2(-back.x, -back.z)
		combatant.hp = minf(combatant.get_stat("max_hp"), combatant.hp + combatant.get_stat("max_hp") * 0.05 * delta)

	velocity.x = wish.x
	velocity.z = wish.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	move_and_slide()
	_update_label()


func _find_player(max_range: float) -> PlayerActor:
	var best: PlayerActor = null
	var best_d := max_range
	for p in get_tree().get_nodes_in_group("players"):
		var pl := p as PlayerActor
		if pl == null or not pl.combatant.is_alive():
			continue
		var d := global_position.distance_to(pl.global_position)
		if d <= best_d:
			best_d = d
			best = pl
	return best


## O dano já foi aplicado no Combatant (via use_skill do atacante).
func on_hit(attacker: Node3D, result: Dictionary) -> void:
	last_attacker = attacker
	if attacker is PlayerActor and target == null:
		target = attacker
	var txt := str(result["damage"]) + ("!" if result.get("crit", false) else "")
	Fx.floating_text(get_parent(), global_position + Vector3(0, 2.2, 0), txt, Color("#ffe066") if result.get("crit", false) else Color.WHITE)
	Fx.hit_burst(get_parent(), global_position + Vector3(0, 1.0, 0), Color("#ffd27f"))
	_update_label()
	if result.get("killed", false):
		_die(attacker)


func _die(killer: Node3D) -> void:
	if _dead:
		return
	_dead = true
	remove_from_group("monsters")
	velocity = Vector3.ZERO
	label.text = ""
	died.emit(self, killer)
	var tw := create_tween()
	tw.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
	tw.tween_callback(queue_free)
