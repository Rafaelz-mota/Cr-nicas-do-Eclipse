class_name Enhancement
extends RefCounted
## Amplificação +0 até +15. Falha consome o custo, mas NUNCA destrói o item
## nem reduz o nível (balance.json -> enhancement.on_failure = "none").


static func next_step(inst: ItemInstance, data: GameDataStore) -> Dictionary:
	var enh: Dictionary = data.balance.get("enhancement", {})
	if inst.enhance >= int(enh.get("max_level", 15)):
		return {}
	for row in enh.get("table", []):
		if int(row.get("to", -1)) == inst.enhance + 1:
			return row
	return {}


## Tenta amplificar. gold_available é só leitura: o chamador desconta o custo
## (CharacterData.enhance_item faz isso). Retorna {"ok","success","cost","reason"}.
static func attempt(inst: ItemInstance, data: GameDataStore, rng: RandomNumberGenerator, gold_available: int) -> Dictionary:
	var def: Dictionary = data.items.get(inst.item_id, {})
	var type: String = def.get("type", "")
	if type != "weapon" and type != "armor":
		return {"ok": false, "success": false, "cost": 0, "reason": "nao_amplificavel"}
	var step := next_step(inst, data)
	if step.is_empty():
		return {"ok": false, "success": false, "cost": 0, "reason": "nivel_maximo"}
	var cost: int = int(step.get("gold", 0))
	if gold_available < cost:
		return {"ok": false, "success": false, "cost": cost, "reason": "gold_insuficiente"}
	var success: bool = rng.randf() < float(step.get("success", 0.0))
	if success:
		inst.enhance += 1
	return {"ok": true, "success": success, "cost": cost, "reason": ""}
