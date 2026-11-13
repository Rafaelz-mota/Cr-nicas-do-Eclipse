class_name RewardService
extends RefCounted
## Resolve recompensas de morte de monstro (XP, Gold, loot). Pura e testável;
## no multiplayer real roda apenas no servidor.


static func grant_kill(character: CharacterData, monster_def: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var gold_range: Array = monster_def.get("gold", [0, 0])
	var gold: int = rng.randi_range(int(gold_range[0]), int(gold_range[1]))
	var items: Array = []
	for drop in monster_def.get("loot", []):
		if rng.randf() < float(drop.get("chance", 0.0)):
			var amount: int = rng.randi_range(int(drop.get("min", 1)), int(drop.get("max", 1)))
			items.append({"id": drop["item"], "count": amount})
	var rewards := {"xp": int(monster_def.get("xp", 0)), "gold": gold, "items": items}
	var summary := character.grant_rewards(rewards)
	character.quest_log.on_event("kill", monster_def["id"], 1)
	return summary
