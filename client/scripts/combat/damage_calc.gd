class_name DamageCalc
extends RefCounted
## Fórmula de dano físico/mágico. Pura e determinística dado o RNG.
## O servidor deve ser a única autoridade que chama isto para dano real.


static func compute(attacker: Combatant, defender: Combatant, skill: Dictionary, rng: RandomNumberGenerator, balance: Dictionary) -> Dictionary:
	var cfg: Dictionary = balance.get("combat", {})
	var dtype: String = skill.get("damage_type", "physical")
	var power: float = float(skill.get("power", 1.0))

	var attack: float
	var defense: float
	var mult := 1.0
	if dtype == "magical":
		attack = attacker.get_stat("magic_attack")
		defense = defender.get_stat("magic_defense")
		mult = attacker.get_stat("magic_damage_mult", 1.0)
	else:
		attack = attacker.get_stat("phys_attack")
		defense = defender.get_stat("defense")

	var k: float = float(cfg.get("defense_constant", 100.0)) + float(attacker.level) * 8.0
	var mitigation: float = defense / (defense + k) if defense > 0.0 else 0.0

	var element: String = skill.get("element", "")
	var resist := 0.0
	if element != "":
		resist = clampf(float(defender.resistances.get(element, 0.0)), -1.0, 0.9)

	var variance: float = rng.randf_range(0.95, 1.05)
	var crit: bool = rng.randf() < attacker.get_stat("crit_chance", 0.05)

	var dmg: float = attack * power * mult * variance
	dmg *= (1.0 - mitigation) * (1.0 - resist) * defender.damage_taken_multiplier()
	if crit:
		dmg *= float(cfg.get("crit_multiplier", 1.5))

	var final_damage: int = maxi(int(cfg.get("min_damage", 1)), int(round(dmg)))
	return {"damage": final_damage, "crit": crit, "type": dtype}
