class_name PlayerActor
extends CharacterBody3D
## Jogador controlável. A lógica de combate vive no Combatant/CharacterData;
## este nó só cuida de movimento, alvo e apresentação.

signal hit_dealt(target: Node3D, result: Dictionary)
signal skill_failed(reason: String)
signal died

const RUN_SPEED := 6.5
const GRAVITY := 25.0

var data: GameDataStore
var character: CharacterData
var combatant: Combatant
var visual: VisualSlot
var rng := RandomNumberGenerator.new()
var touch_move := Vector2.ZERO  # joystick virtual (x direita, y baixo)
var skill_slots: Array = []


func setup(p_data: GameDataStore, p_character: CharacterData) -> void:
	data = p_data
	character = p_character
	rng.randomize()
	add_to_group("players")

	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8
	col.shape = shape
	col.position.y = 0.9
	add_child(col)

	visual = VisualSlot.new()
	add_child(visual)
	visual.use_placeholder(Color("#4aa3ff"))

	combatant = character.build_combatant()
	skill_slots = character.skill_ids()
	character.leveled_up.connect(func(_lv): refresh_stats(true))


func refresh_stats(full_heal: bool = false) -> void:
	combatant.update_stats(character.level, character.derived_stats(), character.clan_passive().get("resistances", {}), full_heal)


func _physics_process(delta: float) -> void:
	if combatant == null:
		return
	if not combatant.is_alive():
		velocity = Vector3.ZERO
		return
	for ev in combatant.tick(delta, data.balance):
		if ev["type"] == "dot":
			Fx.floating_text(get_parent(), global_position + Vector3(0, 2.2, 0), str(ev["damage"]), Color("#ff8844"))

	var v := _keyboard_vector()
	if touch_move.length() > v.length():
		v = touch_move
	var dir := Vector3(v.x, 0.0, v.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	velocity.x = dir.x * RUN_SPEED
	velocity.z = dir.z * RUN_SPEED
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	if dir.length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), 12.0 * delta)
	move_and_slide()


func _keyboard_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		v.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		v.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		v.x += 1.0
	return v.normalized() if v.length() > 1.0 else v


func nearest_monster(max_range: float) -> MonsterActor:
	var best: MonsterActor = null
	var best_d := max_range
	for m in get_tree().get_nodes_in_group("monsters"):
		var mon := m as MonsterActor
		if mon == null or not mon.combatant.is_alive():
			continue
		var d := global_position.distance_to(mon.global_position) - 0.5  # raio do monstro
		if d <= best_d:
			best_d = d
			best = mon
	return best


## Usa a habilidade do slot (0 = básica). Retorna o resultado de Combatant.use_skill.
func use_skill_slot(slot: int) -> Dictionary:
	if slot < 0 or slot >= skill_slots.size() or not combatant.is_alive():
		return {}
	var skill: Dictionary = data.skills[skill_slots[slot]]
	var reason := combatant.can_use(skill)
	if reason != "":
		skill_failed.emit(reason)
		return {"ok": false, "reason": reason}

	var dtype: String = skill.get("damage_type", "physical")
	var needs_target: bool = dtype == "physical" or dtype == "magical" or (dtype == "none" and skill.get("effect_target", "target") == "target")
	var target: MonsterActor = null
	if needs_target:
		target = nearest_monster(float(skill.get("range", 2.0)))
		if target == null:
			skill_failed.emit("sem_alvo")
			return {"ok": false, "reason": "sem_alvo"}
		var to_t := target.global_position - global_position
		rotation.y = atan2(-to_t.x, -to_t.z)

	var result := combatant.use_skill(skill, target.combatant if target else null, rng, data.balance)
	if not result["ok"]:
		skill_failed.emit(result["reason"])
		return result

	var parent := get_parent()
	if target != null:
		var color := Color("#fff1a8") if dtype == "physical" else Color("#9ad0ff")
		if float(skill.get("range", 0.0)) > 4.0:
			Fx.bolt(parent, global_position + Vector3(0, 1.2, 0), target.global_position + Vector3(0, 1.0, 0), color)
		target.on_hit(self, result)
		hit_dealt.emit(target, result)
	elif int(result["healed"]) > 0:
		Fx.floating_text(parent, global_position + Vector3(0, 2.2, 0), "+%d" % int(result["healed"]), Color("#6fd36f"))
	return result


## Chamado pelo monstro quando acerta o jogador (o dano já foi aplicado no Combatant).
func on_hit_taken(result: Dictionary, _source: Node3D) -> void:
	var txt := str(result["damage"]) if int(result["damage"]) > 0 else "absorvido"
	Fx.floating_text(get_parent(), global_position + Vector3(0, 2.2, 0), txt, Color("#ff5555"))
	character.equipment.wear(int(data.balance.get("durability", {}).get("loss_per_hit_taken", 1)), data)
	if not combatant.is_alive():
		died.emit()


func revive_at(pos: Vector3) -> void:
	combatant.revive()
	global_position = pos
	velocity = Vector3.ZERO
