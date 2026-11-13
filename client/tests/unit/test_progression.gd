extends TestCase
## XP, níveis, atributos, missões.

var store: GameDataStore = GameDataStore.load_default()


func _hero() -> CharacterData:
	return CharacterData.create_new(store, "Teste", "vanguarda", "veu_cinzento")


func test_xp_curve_increases_and_caps() -> void:
	var curve := XpCurve.from_balance(store.balance)
	assert_eq(curve.xp_to_next(1), 100)
	for l in range(1, 49):
		assert_true(curve.xp_to_next(l + 1) > curve.xp_to_next(l), "curva crescente no nível %d" % l)
	assert_eq(curve.xp_to_next(50), 0, "sem XP além do nível 50")


func test_level_up_grants_points_and_emits() -> void:
	var ch := _hero()
	var got: Array = []
	ch.leveled_up.connect(func(lv): got.append(lv))
	var gained := ch.add_xp(100)
	assert_eq(gained, 1)
	assert_eq(ch.level, 2)
	assert_eq(ch.free_points, 3)
	assert_eq(got, [2])


func test_multiple_levels_at_once_and_cap_at_50() -> void:
	var ch := _hero()
	ch.add_xp(100000000)
	assert_eq(ch.level, 50)
	assert_eq(ch.xp, 0)
	assert_eq(ch.add_xp(1000), 0, "nível máximo não sobe mais")


func test_allocate_points() -> void:
	var ch := _hero()
	assert_false(ch.allocate_point("forca"), "sem pontos livres")
	ch.add_xp(100)
	var before: float = ch.total_attributes()["forca"]
	assert_true(ch.allocate_point("forca"))
	assert_approx(ch.total_attributes()["forca"], before + 1.0)
	assert_false(ch.allocate_point("sorte"), "atributo inexistente")


func test_gold_cannot_go_negative() -> void:
	var ch := _hero()
	ch.add_gold(50)
	assert_false(ch.spend_gold(51))
	assert_eq(ch.gold, 50)
	assert_true(ch.spend_gold(50))
	assert_eq(ch.gold, 0)
	assert_false(ch.spend_gold(-5), "gasto negativo rejeitado (anti-exploit)")
	ch.add_gold(-100)
	assert_eq(ch.gold, 0, "ganho negativo ignorado")


func test_quest_chain_and_rewards() -> void:
	var ch := _hero()
	var log := ch.quest_log
	assert_eq(log.can_accept("q_trilha_cinzenta", 1), "pre_requisito")
	assert_true(log.accept("q_primeiros_passos", 1))
	assert_false(log.accept("q_primeiros_passos", 1), "não aceita duas vezes")
	assert_false(log.is_ready("q_primeiros_passos"))
	for i in range(3):
		log.on_event("kill", "gosmante_musgoso")
	log.on_event("kill", "gosmante_musgoso")  # excesso não passa do limite
	assert_true(log.is_ready("q_primeiros_passos"))
	var rewards := log.turn_in("q_primeiros_passos")
	assert_eq(int(rewards["xp"]), 120)
	var summary := ch.grant_rewards(rewards)
	assert_eq(summary["gold"], 50)
	assert_eq(ch.inventory.count_of("pocao_vida_pequena"), 5, "3 iniciais + 2 de recompensa")
	assert_eq(log.can_accept("q_trilha_cinzenta", ch.level), "")
	assert_eq(log.can_accept("q_primeiros_passos", ch.level), "concluida")


func test_npc_offers_follow_chain() -> void:
	var ch := _hero()
	assert_eq(ch.quest_log.available_for_npc("maren_guardia", 1), ["q_primeiros_passos"])
