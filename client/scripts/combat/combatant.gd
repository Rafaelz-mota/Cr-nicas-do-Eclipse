class_name Combatant
extends RefCounted
## Estado de combate de qualquer entidade (jogador ou monstro).
## Sem nós, sem física: a simulação de dano pode rodar no servidor.

var id: String = ""
var display_name: String = ""
var level: int = 1
var stats: Dictionary = {}
var resistances: Dictionary = {}
var hp: float = 1.0
var mp: float = 0.0
var cooldowns: Dictionary = {}
var effects: Array = []


func setup(p_id: String, p_name: String, p_level: int, p_stats: Dictionary, p_resist: Dictionary = {}) -> void:
	id = p_id
	display_name = p_name
	level = p_level
	stats = p_stats.duplicate()
	resistances = p_resist.duplicate()
	hp = get_stat("max_hp", 1.0)
	mp = get_stat("max_mp", 0.0)


## Atualiza estatísticas (nível, equipamento). Mantém a proporção de vida/mana,
## a menos que full_heal seja verdadeiro.
func update_stats(p_level: int, p_stats: Dictionary, p_resist: Dictionary, full_heal: bool = false) -> void:
	var hp_ratio: float = hp / maxf(1.0, get_stat("max_hp", 1.0))
	var mp_ratio: float = mp / maxf(1.0, get_stat("max_mp", 1.0))
	level = p_level
	stats = p_stats.duplicate()
	resistances = p_resist.duplicate()
	if full_heal:
		hp = get_stat("max_hp", 1.0)
		mp = get_stat("max_mp", 0.0)
	else:
		hp = clampf(get_stat("max_hp", 1.0) * hp_ratio, 1.0, get_stat("max_hp", 1.0))
		mp = clampf(get_stat("max_mp", 0.0) * mp_ratio, 0.0, get_stat("max_mp", 0.0))


func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	return float(stats.get(stat_name, default_value))


func is_alive() -> bool:
	return hp > 0.0


func revive() -> void:
	hp = get_stat("max_hp", 1.0)
	mp = get_stat("max_mp", 0.0)
	cooldowns.clear()
	effects.clear()


## Multiplicador total de dano recebido (ex.: efeito "marcado").
func damage_taken_multiplier() -> float:
	var m := 1.0
	for e in effects:
		m *= float(e.get("damage_taken_mult", 1.0))
	return m


## Aplica dano. Escudos absorvem primeiro. Retorna {"taken", "absorbed"}.
func receive_damage(amount: int) -> Dictionary:
	var remaining: float = float(amount)
	var absorbed := 0.0
	for e in effects:
		var left: float = float(e.get("absorb_left", 0.0))
		if left > 0.0 and remaining > 0.0:
			var used := minf(left, remaining)
			e["absorb_left"] = left - used
			remaining -= used
			absorbed += used
	hp = maxf(0.0, hp - remaining)
	return {"taken": int(remaining), "absorbed": int(absorbed)}


func heal(amount: int) -> int:
	if not is_alive():
		return 0
	var before := hp
	hp = minf(get_stat("max_hp", 1.0), hp + float(amount))
	return int(round(hp - before))


func apply_effect(effect: Dictionary, source: Combatant) -> void:
	var e := effect.duplicate(true)
	e["remaining"] = float(effect.get("duration", 0.0))
	e["tick_timer"] = 0.0
	e["absorb_left"] = float(effect.get("absorb", 0.0))
	var dot_power: float = float(effect.get("dot_power", 0.0))
	if dot_power > 0.0 and source != null:
		e["dot_damage"] = int(round(maxf(source.get_stat("magic_attack"), source.get_stat("phys_attack")) * dot_power))
	# Mesmo efeito reaplicado apenas renova.
	for i in range(effects.size()):
		if effects[i].get("id", "") == e.get("id", "x"):
			effects[i] = e
			return
	effects.append(e)


## Avança recargas, regeneração e efeitos. Retorna eventos (ex.: dano contínuo).
func tick(delta: float, balance: Dictionary = {}) -> Array:
	var events: Array = []
	if not is_alive():
		return events
	for sid in cooldowns.keys():
		cooldowns[sid] = maxf(0.0, float(cooldowns[sid]) - delta)
	var cfg: Dictionary = balance.get("combat", {})
	mp = minf(get_stat("max_mp", 0.0), mp + float(cfg.get("mana_regen_per_sec", 0.0)) * delta)
	hp = minf(get_stat("max_hp", 1.0), hp + float(cfg.get("hp_regen_per_sec", 0.0)) * delta)

	var expired: Array = []
	for e in effects:
		var active_time: float = minf(delta, maxf(0.0, float(e["remaining"])))
		e["remaining"] = float(e["remaining"]) - delta
		var interval: float = float(e.get("tick_interval", 0.0))
		var dot: int = int(e.get("dot_damage", 0))
		if interval > 0.0 and dot > 0:
			e["tick_timer"] = float(e["tick_timer"]) + active_time
			while float(e["tick_timer"]) >= interval - 0.0001:
				e["tick_timer"] = float(e["tick_timer"]) - interval
				var r := receive_damage(dot)
				events.append({"type": "dot", "effect": e.get("id", ""), "damage": r["taken"]})
				if not is_alive():
					break
		var shield_gone: bool = float(e.get("absorb", 0.0)) > 0.0 and float(e["absorb_left"]) <= 0.0
		if float(e["remaining"]) <= 0.0 or shield_gone:
			expired.append(e)
	for e in expired:
		effects.erase(e)
	return events


## Motivo pelo qual a habilidade não pode ser usada ("" = pode).
func can_use(skill: Dictionary) -> String:
	if not is_alive():
		return "morto"
	if float(cooldowns.get(skill.get("id", ""), 0.0)) > 0.0:
		return "recarga"
	if mp < float(skill.get("mana_cost", 0.0)):
		return "mana"
	if level < int(skill.get("level_required", 1)):
		return "nivel"
	return ""


## Usa uma habilidade. O chamador valida alcance/posição (o Combatant não tem posição).
func use_skill(skill: Dictionary, target: Combatant, rng: RandomNumberGenerator, balance: Dictionary) -> Dictionary:
	var reason := can_use(skill)
	if reason != "":
		return {"ok": false, "reason": reason}
	var dtype: String = skill.get("damage_type", "physical")
	var targets_enemy: bool = dtype == "physical" or dtype == "magical" or (dtype == "none" and skill.get("effect_target", "target") == "target")
	if targets_enemy and (target == null or not target.is_alive()):
		return {"ok": false, "reason": "sem_alvo"}

	mp -= float(skill.get("mana_cost", 0.0))
	cooldowns[skill["id"]] = float(skill.get("cooldown", 0.0))

	var result := {"ok": true, "skill": skill["id"], "damage": 0, "crit": false, "healed": 0, "killed": false, "absorbed": 0}
	if dtype == "heal":
		result["healed"] = heal(int(round(get_stat("magic_attack") * float(skill.get("power", 1.0)))))
	elif dtype == "physical" or dtype == "magical":
		var calc := DamageCalc.compute(self, target, skill, rng, balance)
		var applied := target.receive_damage(int(calc["damage"]))
		result["damage"] = applied["taken"]
		result["absorbed"] = applied["absorbed"]
		result["crit"] = calc["crit"]
		result["killed"] = not target.is_alive()

	if skill.has("effect"):
		var recipient: Combatant = self if skill.get("effect_target", "target") == "self" else target
		if recipient != null and recipient.is_alive():
			recipient.apply_effect(skill["effect"], self)
	return result
