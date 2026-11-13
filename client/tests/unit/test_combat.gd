extends TestCase
## Estatísticas, dano, habilidades, efeitos e recompensas.

var store: GameDataStore = GameDataStore.load_default()


func _rng(seed_value: int = 1234) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func _dummy(hp: float, defense: float = 0.0) -> Combatant:
	var c := Combatant.new()
	c.setup("dummy", "Alvo", 1, {"max_hp": hp, "max_mp": 0.0, "defense": defense, "magic_defense": 0.0, "phys_attack": 10.0, "crit_chance": 0.0})
	return c


func _hero(class_id: String = "vanguarda", clan_id: String = "veu_cinzento") -> CharacterData:
	return CharacterData.create_new(store, "Teste", class_id, clan_id)


func test_derive_stats_scale_with_attributes() -> void:
	var low := CombatStats.derive(1, {"forca": 5, "vitalidade": 5})
	var high := CombatStats.derive(1, {"forca": 20, "vitalidade": 20})
	assert_true(high["phys_attack"] > low["phys_attack"])
	assert_true(high["max_hp"] > low["max_hp"])


func test_clan_passive_applies() -> void:
	var base := CombatStats.derive(1, {"vitalidade": 10})
	var clan := CombatStats.derive(1, {"vitalidade": 10}, {}, {"max_hp_mult": 1.10})
	assert_approx(float(clan["max_hp"]), float(base["max_hp"]) * 1.10, 0.01)


func test_damage_is_deterministic_with_same_seed() -> void:
	var hero := _hero().build_combatant()
	var skill: Dictionary = store.skills["golpe_firme"]
	var a := DamageCalc.compute(hero, _dummy(100.0), skill, _rng(7), store.balance)
	var b := DamageCalc.compute(hero, _dummy(100.0), skill, _rng(7), store.balance)
	assert_eq(a["damage"], b["damage"])


func test_defense_reduces_damage() -> void:
	var hero := _hero().build_combatant()
	var skill: Dictionary = store.skills["golpe_firme"]
	var soft := DamageCalc.compute(hero, _dummy(100.0, 0.0), skill, _rng(5), store.balance)
	var hard := DamageCalc.compute(hero, _dummy(100.0, 200.0), skill, _rng(5), store.balance)
	assert_true(hard["damage"] < soft["damage"])


func test_minimum_damage_is_one() -> void:
	var weak := Combatant.new()
	weak.setup("w", "Fraco", 1, {"max_hp": 10.0, "phys_attack": 0.0, "crit_chance": 0.0})
	var r := DamageCalc.compute(weak, _dummy(100.0, 9999.0), store.skills["golpe_firme"], _rng(), store.balance)
	assert_eq(r["damage"], 1)


func test_skill_uses_mana_and_cooldown() -> void:
	var mage := _hero("arcanista").build_combatant()
	var target := _dummy(5000.0)
	var skill: Dictionary = store.skills["raio_runico"]
	var mp_before := mage.mp
	var r1 := mage.use_skill(skill, target, _rng(), store.balance)
	assert_true(r1["ok"])
	assert_approx(mage.mp, mp_before - 5.0)
	var r2 := mage.use_skill(skill, target, _rng(), store.balance)
	assert_false(r2["ok"])
	assert_eq(r2["reason"], "recarga")
	mage.tick(2.0)
	assert_eq(mage.can_use(skill), "")


func test_skill_blocked_without_mana_or_level() -> void:
	var hero := _hero().build_combatant()
	hero.mp = 0.0
	assert_eq(hero.can_use(store.skills["investida_ruptura"]), "mana")
	hero.mp = 100.0
	assert_eq(hero.can_use(store.skills["investida_ruptura"]), "nivel", "nível 1 < nível 3")


func test_kill_and_dead_target_rejected() -> void:
	var hero := _hero().build_combatant()
	var target := _dummy(1.0)
	var r := hero.use_skill(store.skills["golpe_firme"], target, _rng(), store.balance)
	assert_true(r["killed"])
	hero.tick(5.0)
	var again := hero.use_skill(store.skills["golpe_firme"], target, _rng(), store.balance)
	assert_false(again["ok"])
	assert_eq(again["reason"], "sem_alvo")


func test_heal_skill_restores_hp_capped() -> void:
	var s := _hero("sentinela").build_combatant()
	s.hp = 10.0
	s.level = 5
	var r := s.use_skill(store.skills["luz_restauradora"], null, _rng(), store.balance)
	assert_true(r["ok"])
	assert_true(s.hp > 10.0 and s.hp <= s.get_stat("max_hp"))


func test_burn_damage_over_time() -> void:
	var mage_data := _hero("arcanista")
	mage_data.level = 3
	var mage := mage_data.build_combatant()
	var target := _dummy(100000.0)
	mage.use_skill(store.skills["chama_orbital"], target, _rng(), store.balance)
	var hp_after_hit := target.hp
	var events := target.tick(1.0)
	assert_true(events.size() >= 1, "DoT deve disparar")
	assert_true(target.hp < hp_after_hit)
	target.tick(10.0)
	assert_eq(target.effects.size(), 0, "efeito expira")


func test_shield_absorbs_damage() -> void:
	var c := _dummy(100.0)
	c.apply_effect(store.skills["costela_de_marfim"]["effect"], c)
	var r := c.receive_damage(40)
	assert_eq(r["absorbed"], 40)
	assert_approx(c.hp, 100.0)
	var r2 := c.receive_damage(40)  # 20 restantes de escudo
	assert_eq(r2["absorbed"], 20)
	assert_approx(c.hp, 80.0)


func test_marked_effect_increases_damage_taken() -> void:
	var hero := _hero().build_combatant()
	var plain := _dummy(100.0)
	var marked := _dummy(100.0)
	marked.apply_effect(store.skills["olhar_do_veu"]["effect"], hero)
	var skill: Dictionary = store.skills["golpe_firme"]
	var a := DamageCalc.compute(hero, plain, skill, _rng(9), store.balance)
	var b := DamageCalc.compute(hero, marked, skill, _rng(9), store.balance)
	assert_true(b["damage"] > a["damage"])


func test_fire_resistance_from_clan() -> void:
	var fire_clan := _hero("arcanista", "brasa_lirio").build_combatant()
	var other := _hero("arcanista", "veu_cinzento").build_combatant()
	assert_approx(float(fire_clan.resistances.get("fogo", 0.0)), 0.2)
	assert_approx(float(other.resistances.get("fogo", 0.0)), 0.0)


func test_any_class_with_any_clan() -> void:
	for cid in store.classes:
		for kid in store.clans:
			var ch := CharacterData.create_new(store, "T", cid, kid)
			var c := ch.build_combatant()
			assert_true(c.get_stat("max_hp") > 0.0, "%s+%s tem vida" % [cid, kid])
			assert_true(ch.skill_ids().size() >= 3, "%s+%s tem habilidades de classe e de clã" % [cid, kid])


func test_monster_rewards_and_quest_progress() -> void:
	var hero := _hero()
	hero.quest_log.accept("q_primeiros_passos", hero.level)
	var def: Dictionary = store.monsters["gosmante_musgoso"]
	var xp_before := hero.xp
	RewardService.grant_kill(hero, def, _rng())
	assert_true(hero.xp > xp_before or hero.level > 1)
	assert_true(hero.gold >= int(def["gold"][0]))
	assert_eq(hero.quest_log.active["q_primeiros_passos"]["progress"][0], 1)
