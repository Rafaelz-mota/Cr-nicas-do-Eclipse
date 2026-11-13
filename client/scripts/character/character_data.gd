class_name CharacterData
extends RefCounted
## Dados persistentes de um personagem. TODA mutação de XP, Gold, inventário e
## equipamento passa por métodos daqui — é o ponto que o servidor autoritativo
## (ASP.NET Core) deve assumir. O cliente nunca deve ser confiável para isso.

signal leveled_up(new_level: int)

var data: GameDataStore
var char_name: String = "Viajante"
var class_id: String = "vanguarda"
var clan_id: String = "veu_cinzento"
var level: int = 1
var xp: int = 0
var gold: int = 0
var free_points: int = 0
var allocated: Dictionary = {}  # atributos distribuídos pelo jogador
var inventory: Inventory
var equipment: Equipment
var quest_log: QuestLog
var xp_curve: XpCurve


static func create_new(p_data: GameDataStore, p_name: String, p_class: String, p_clan: String) -> CharacterData:
	var c := CharacterData.new()
	c.data = p_data
	c.char_name = p_name
	c.class_id = p_class
	c.clan_id = p_clan
	c.xp_curve = XpCurve.from_balance(p_data.balance)
	c.inventory = Inventory.new(p_data)
	c.equipment = Equipment.new()
	c.quest_log = QuestLog.new(p_data)
	# Qualquer classe pode ser combinada com qualquer clã.
	for item_id in p_data.classes[p_class].get("starter_items", []):
		c.inventory.add_item(item_id, 3 if p_data.items[item_id].get("type", "") == "consumable" else 1)
	for inst in c.inventory.slots.duplicate():
		var t: String = p_data.items[inst.item_id].get("type", "")
		if t == "weapon" or t == "armor":
			c.equipment.equip(c.inventory, inst.uid, 1, c.allowed_weapon_types())
	return c


const SAVE_VERSION := 1


## Estado completo e serializável do personagem (base do salvamento local e,
## no futuro, da persistência no servidor).
func to_dict() -> Dictionary:
	var inv: Array = []
	for s in inventory.slots:
		inv.append(s.to_dict())
	var worn := {}
	for slot in equipment.worn:
		worn[slot] = equipment.worn[slot].to_dict()
	return {
		"version": SAVE_VERSION,
		"name": char_name, "class_id": class_id, "clan_id": clan_id,
		"level": level, "xp": xp, "gold": gold,
		"free_points": free_points, "allocated": allocated.duplicate(),
		"inventory": inv, "equipment": worn,
		"quests_active": quest_log.active.duplicate(true),
		"quests_completed": quest_log.completed.keys(),
	}


## Reconstrói o personagem validando contra os dados do jogo. Retorna null se o
## salvamento for inválido (classe/clã inexistente). Itens desconhecidos são
## descartados e valores fora do limite são ajustados.
static func from_dict(p_data: GameDataStore, d: Dictionary) -> CharacterData:
	var cid: String = str(d.get("class_id", ""))
	var kid: String = str(d.get("clan_id", ""))
	if not p_data.classes.has(cid) or not p_data.clans.has(kid):
		return null
	var c := CharacterData.new()
	c.data = p_data
	c.char_name = str(d.get("name", "Viajante"))
	c.class_id = cid
	c.clan_id = kid
	c.xp_curve = XpCurve.from_balance(p_data.balance)
	c.inventory = Inventory.new(p_data)
	c.equipment = Equipment.new()
	c.quest_log = QuestLog.new(p_data)

	c.level = clampi(int(d.get("level", 1)), 1, c.xp_curve.max_level)
	var need: int = c.xp_curve.xp_to_next(c.level)
	c.xp = clampi(int(d.get("xp", 0)), 0, maxi(0, need - 1))
	c.gold = maxi(0, int(d.get("gold", 0)))
	c.free_points = maxi(0, int(d.get("free_points", 0)))
	var alloc: Dictionary = d.get("allocated", {})
	for a in CombatStats.ATTRIBUTES:
		if alloc.has(a):
			c.allocated[a] = maxi(0, int(alloc[a]))

	for raw in d.get("inventory", []):
		var inst := _restore_item(p_data, raw)
		if inst != null:
			c.inventory.add_instance(inst)
	var worn: Dictionary = d.get("equipment", {})
	for slot in worn:
		var inst := _restore_item(p_data, worn[slot])
		if inst == null or not Equipment.SLOTS.has(slot):
			continue
		if p_data.items[inst.item_id].get("slot", "") != slot:
			continue
		c.equipment.worn[slot] = inst

	var qa: Dictionary = d.get("quests_active", {})
	for qid in qa:
		if not p_data.quests.has(qid):
			continue
		var n: int = (p_data.quests[qid].get("objectives", []) as Array).size()
		var prog: Array = []
		var saved: Array = qa[qid].get("progress", [])
		for i in range(n):
			var need_i: int = int(p_data.quests[qid]["objectives"][i].get("count", 1))
			prog.append(clampi(int(saved[i]) if i < saved.size() else 0, 0, need_i))
		c.quest_log.active[qid] = {"progress": prog}
	for qid in d.get("quests_completed", []):
		if p_data.quests.has(qid):
			c.quest_log.completed[qid] = true
	return c


static func _restore_item(p_data: GameDataStore, raw: Variant) -> ItemInstance:
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var inst := ItemInstance.from_dict(raw)
	var def: Dictionary = p_data.items.get(inst.item_id, {})
	if def.is_empty() or inst.uid == "":
		return null
	var max_stack: int = int(def.get("max_stack", 1)) if bool(def.get("stackable", false)) else 1
	inst.count = clampi(inst.count, 1, max_stack)
	inst.enhance = clampi(inst.enhance, 0, int(p_data.balance.get("enhancement", {}).get("max_level", 15)))
	inst.durability = clampi(inst.durability, 0, int(def.get("durability_max", 0)))
	return inst


func allowed_weapon_types() -> Array:
	return data.classes.get(class_id, {}).get("weapon_types", [])


func total_attributes() -> Dictionary:
	var cls: Dictionary = data.classes[class_id]
	var out := {}
	for a in CombatStats.ATTRIBUTES:
		out[a] = float(cls["base_attributes"].get(a, 0)) \
			+ float(cls["growth"].get(a, 0)) * float(level - 1) \
			+ float(allocated.get(a, 0))
	return out


func clan_passive() -> Dictionary:
	return data.clans.get(clan_id, {}).get("passive", {})


func derived_stats() -> Dictionary:
	return CombatStats.derive(level, total_attributes(), equipment.bonus_stats(data), clan_passive())


func build_combatant() -> Combatant:
	var c := Combatant.new()
	c.setup(char_name, char_name, level, derived_stats(), clan_passive().get("resistances", {}))
	return c


## Ids das habilidades disponíveis: classe primeiro, depois técnicas do clã.
func skill_ids() -> Array:
	var out: Array = []
	out.append_array(data.classes[class_id].get("skills", []))
	out.append_array(data.clans.get(clan_id, {}).get("techniques", []))
	return out


## Concede XP. Retorna quantos níveis subiu.
func add_xp(amount: int) -> int:
	if amount <= 0 or level >= xp_curve.max_level:
		return 0
	xp += amount
	var gained := 0
	var points: int = int(data.balance.get("attributes", {}).get("points_per_level", 3))
	while level < xp_curve.max_level and xp >= xp_curve.xp_to_next(level):
		xp -= xp_curve.xp_to_next(level)
		level += 1
		free_points += points
		gained += 1
	if level >= xp_curve.max_level:
		xp = 0
	if gained > 0:
		leveled_up.emit(level)
	return gained


func add_gold(amount: int) -> void:
	if amount > 0:
		gold += amount


func spend_gold(amount: int) -> bool:
	if amount < 0 or gold < amount:
		return false
	gold -= amount
	return true


## Distribui pontos livres em um atributo.
func allocate_point(attr: String) -> bool:
	if free_points <= 0 or not CombatStats.ATTRIBUTES.has(attr):
		return false
	free_points -= 1
	allocated[attr] = int(allocated.get(attr, 0)) + 1
	return true


## Concede recompensas de missão/monstro. Retorna o que realmente entrou.
func grant_rewards(rewards: Dictionary) -> Dictionary:
	var summary := {"xp": int(rewards.get("xp", 0)), "gold": int(rewards.get("gold", 0)), "items": [], "overflow": []}
	add_xp(summary["xp"])
	add_gold(summary["gold"])
	for it in rewards.get("items", []):
		var left := inventory.add_item(it["id"], int(it.get("count", 1)))
		if left > 0:
			summary["overflow"].append({"id": it["id"], "count": left})
		if left < int(it.get("count", 1)):
			summary["items"].append({"id": it["id"], "count": int(it.get("count", 1)) - left})
	return summary


func equip_item(uid: String) -> Dictionary:
	return equipment.equip(inventory, uid, level, allowed_weapon_types())


## Usa um consumível. Retorna o efeito aplicado ({} se falhou).
func use_consumable(uid: String) -> Dictionary:
	var inst := inventory.find_uid(uid)
	if inst == null:
		return {}
	var def: Dictionary = data.items.get(inst.item_id, {})
	if def.get("type", "") != "consumable":
		return {}
	var effect: Dictionary = (def.get("effect", {}) as Dictionary).duplicate()
	inst.count -= 1
	if inst.count <= 0:
		inventory.take_uid(uid)
	return effect


## Amplifica um item (no inventário ou vestido). Desconta o Gold.
func enhance_item(uid: String, rng: RandomNumberGenerator) -> Dictionary:
	var inst := inventory.find_uid(uid)
	if inst == null:
		for slot in equipment.worn:
			if equipment.worn[slot].uid == uid:
				inst = equipment.worn[slot]
	if inst == null:
		return {"ok": false, "success": false, "cost": 0, "reason": "item_inexistente"}
	var result := Enhancement.attempt(inst, data, rng, gold)
	if result["ok"]:
		spend_gold(int(result["cost"]))
	return result


func repair_equipment() -> bool:
	var cost := equipment.repair_cost(data)
	if cost <= 0 or not spend_gold(cost):
		return false
	equipment.repair_all(data)
	return true
