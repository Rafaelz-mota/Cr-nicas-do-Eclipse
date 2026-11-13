class_name CombatStats
extends RefCounted
## Converte atributos básicos em estatísticas derivadas de combate.
## Lógica pura: o servidor autoritativo deve aplicar as mesmas fórmulas.

const ATTRIBUTES: Array[String] = ["forca", "destreza", "inteligencia", "vitalidade", "espirito"]


## attrs: atributos totais. bonus: soma dos equipamentos (attack, defense, hp...).
## passive: passiva hereditária do clã (crit_chance_add, magic_damage_mult, max_hp_mult).
static func derive(level: int, attrs: Dictionary, bonus: Dictionary = {}, passive: Dictionary = {}) -> Dictionary:
	var f: float = float(attrs.get("forca", 0.0))
	var d: float = float(attrs.get("destreza", 0.0))
	var i: float = float(attrs.get("inteligencia", 0.0))
	var v: float = float(attrs.get("vitalidade", 0.0))
	var e: float = float(attrs.get("espirito", 0.0))
	var lv: float = float(level)

	var s := {
		"max_hp": 60.0 + v * 12.0 + lv * 10.0 + float(bonus.get("hp", 0.0)),
		"max_mp": 30.0 + i * 5.0 + e * 6.0 + lv * 3.0 + float(bonus.get("mp", 0.0)),
		"phys_attack": f * 2.0 + d * 0.5 + lv * 1.5 + float(bonus.get("attack", 0.0)),
		"magic_attack": i * 2.2 + lv * 1.5 + float(bonus.get("magic_attack", 0.0)),
		"defense": v * 1.0 + f * 0.3 + float(bonus.get("defense", 0.0)),
		"magic_defense": e * 1.2 + i * 0.3 + float(bonus.get("magic_defense", 0.0)),
		"crit_chance": 0.05 + d * 0.002 + float(bonus.get("crit_chance", 0.0)),
		"magic_damage_mult": 1.0,
	}

	s["crit_chance"] = float(s["crit_chance"]) + float(passive.get("crit_chance_add", 0.0))
	s["magic_damage_mult"] = float(passive.get("magic_damage_mult", 1.0))
	s["max_hp"] = float(s["max_hp"]) * float(passive.get("max_hp_mult", 1.0))
	s["crit_chance"] = clampf(float(s["crit_chance"]), 0.0, 0.6)
	return s
