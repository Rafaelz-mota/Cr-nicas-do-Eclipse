class_name Equipment
extends RefCounted
## Equipamento vestido. Amplificação multiplica os atributos base; item com
## durabilidade zerada (quebrado) para de dar bônus.

const SLOTS: Array[String] = ["arma", "cabeca", "peito", "pernas", "botas", "acessorio"]

var worn: Dictionary = {}  # slot -> ItemInstance


## Tenta equipar o item (por uid) vindo do inventário.
## Retorna {"ok": bool, "reason": String}.
func equip(inv: Inventory, uid: String, char_level: int, allowed_weapon_types: Array) -> Dictionary:
	var inst: ItemInstance = inv.find_uid(uid)
	if inst == null:
		return {"ok": false, "reason": "item_inexistente"}
	var def: Dictionary = inv.data.items.get(inst.item_id, {})
	var type: String = def.get("type", "")
	if type != "weapon" and type != "armor":
		return {"ok": false, "reason": "nao_equipavel"}
	var slot: String = def.get("slot", "")
	if not SLOTS.has(slot):
		return {"ok": false, "reason": "slot_invalido"}
	if char_level < int(def.get("level_req", 1)):
		return {"ok": false, "reason": "nivel"}
	if type == "weapon" and not allowed_weapon_types.has(def.get("weapon_type", "")):
		return {"ok": false, "reason": "tipo_de_arma"}

	inv.take_uid(uid)
	var previous: ItemInstance = worn.get(slot, null)
	worn[slot] = inst
	if previous != null:
		inv.add_instance(previous)  # cabe: acabamos de liberar um espaço
	return {"ok": true, "reason": ""}


func unequip(inv: Inventory, slot: String) -> Dictionary:
	var inst: ItemInstance = worn.get(slot, null)
	if inst == null:
		return {"ok": false, "reason": "vazio"}
	if inv.is_full():
		return {"ok": false, "reason": "inventario_cheio"}
	inv.add_instance(inst)
	worn.erase(slot)
	return {"ok": true, "reason": ""}


func bonus_stats(data: GameDataStore) -> Dictionary:
	var out := {}
	var per_level: float = float(data.balance.get("enhancement", {}).get("stat_bonus_per_level", 0.06))
	for slot in worn:
		var inst: ItemInstance = worn[slot]
		var def: Dictionary = data.items.get(inst.item_id, {})
		if int(def.get("durability_max", 0)) > 0 and inst.durability <= 0:
			continue  # quebrado
		var mult := 1.0 + float(inst.enhance) * per_level
		var stats: Dictionary = def.get("stats", {})
		for k in stats:
			out[k] = float(out.get(k, 0.0)) + float(stats[k]) * mult
	return out


## Desgaste ao receber golpe: reduz durabilidade das peças vestidas.
func wear(amount: int, data: GameDataStore) -> void:
	for slot in worn:
		var inst: ItemInstance = worn[slot]
		if int(data.items.get(inst.item_id, {}).get("durability_max", 0)) > 0:
			inst.durability = maxi(0, inst.durability - amount)


func repair_cost(data: GameDataStore) -> int:
	var per_point: int = int(data.balance.get("durability", {}).get("repair_gold_per_point", 2))
	var total := 0
	for slot in worn:
		var inst: ItemInstance = worn[slot]
		var max_d: int = int(data.items.get(inst.item_id, {}).get("durability_max", 0))
		total += maxi(0, max_d - inst.durability) * per_point
	return total


func repair_all(data: GameDataStore) -> void:
	for slot in worn:
		var inst: ItemInstance = worn[slot]
		inst.durability = int(data.items.get(inst.item_id, {}).get("durability_max", inst.durability))
