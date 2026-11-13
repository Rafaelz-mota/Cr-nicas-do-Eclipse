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
