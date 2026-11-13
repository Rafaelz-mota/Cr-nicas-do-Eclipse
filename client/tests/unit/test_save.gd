extends TestCase
## Salvamento: ida e volta, validação de dados adulterados e arquivo corrompido.

const TMP := "user://test_save_tmp.json"

var store: GameDataStore = GameDataStore.load_default()


func _rich_character() -> CharacterData:
	var ch := CharacterData.create_new(store, "Aventureira", "arcanista", "brasa_lirio")
	ch.add_xp(150)
	ch.add_gold(777)
	ch.allocate_point("inteligencia")
	ch.equipment.worn["arma"].enhance = 5
	ch.equipment.worn["arma"].durability = 11
	ch.inventory.add_item("gosma_musgosa", 7)
	ch.quest_log.accept("q_primeiros_passos", ch.level)
	ch.quest_log.on_event("kill", "gosmante_musgoso")
	return ch


func _json_roundtrip(d: Dictionary) -> Dictionary:
	# Reproduz o efeito real do disco: números viram float, dicionários são recriados.
	return JSON.parse_string(JSON.stringify(d))


func test_roundtrip_preserves_everything() -> void:
	var a := _rich_character()
	var b := CharacterData.from_dict(store, _json_roundtrip(a.to_dict()))
	assert_true(b != null)
	assert_eq(b.char_name, "Aventureira")
	assert_eq(b.class_id, "arcanista")
	assert_eq(b.clan_id, "brasa_lirio")
	assert_eq(b.level, a.level)
	assert_eq(b.xp, a.xp)
	assert_eq(b.gold, 777)
	assert_eq(b.free_points, a.free_points)
	assert_eq(b.allocated, {"inteligencia": 1})
	assert_eq(b.inventory.count_of("gosma_musgosa"), 7)
	assert_eq(b.equipment.worn["arma"].enhance, 5)
	assert_eq(b.equipment.worn["arma"].durability, 11)
	assert_eq(b.quest_log.active["q_primeiros_passos"]["progress"], [1])
	assert_eq(b.derived_stats()["max_hp"], a.derived_stats()["max_hp"], "mesmas estatísticas")


func test_completed_quests_persist() -> void:
	var a := _rich_character()
	a.quest_log.on_event("kill", "gosmante_musgoso", 5)
	a.quest_log.turn_in("q_primeiros_passos")
	var b := CharacterData.from_dict(store, _json_roundtrip(a.to_dict()))
	assert_true(b.quest_log.completed.has("q_primeiros_passos"))
	assert_false(b.quest_log.active.has("q_primeiros_passos"))
	assert_eq(b.quest_log.can_accept("q_trilha_cinzenta", b.level), "")


func test_new_items_after_load_get_unique_uids() -> void:
	var a := _rich_character()
	var b := CharacterData.from_dict(store, _json_roundtrip(a.to_dict()))
	b.inventory.add_item("espada_treino", 1)
	var seen := {}
	for s in b.inventory.slots:
		assert_false(seen.has(s.uid), "uid duplicado após carregar: " + s.uid)
		seen[s.uid] = true
	for slot in b.equipment.worn:
		var u: String = b.equipment.worn[slot].uid
		assert_false(seen.has(u), "uid de equipado repetido: " + u)
		seen[u] = true


func test_invalid_class_or_clan_rejected() -> void:
	var d := _json_roundtrip(_rich_character().to_dict())
	d["class_id"] = "classe_inexistente"
	assert_true(CharacterData.from_dict(store, d) == null)
	d = _json_roundtrip(_rich_character().to_dict())
	d["clan_id"] = "cla_inexistente"
	assert_true(CharacterData.from_dict(store, d) == null)


func test_tampered_values_are_clamped() -> void:
	var d := _json_roundtrip(_rich_character().to_dict())
	d["level"] = 9999
	d["gold"] = -500
	d["free_points"] = -3
	d["xp"] = 999999999
	var b := CharacterData.from_dict(store, d)
	assert_eq(b.level, 50, "nível limitado ao máximo")
	assert_eq(b.gold, 0)
	assert_eq(b.free_points, 0)
	assert_eq(b.xp, 0, "XP no nível máximo é zero")


func test_tampered_items_are_sanitized() -> void:
	var d := _json_roundtrip(_rich_character().to_dict())
	d["inventory"].append({"uid": "i99999999", "item_id": "item_que_nao_existe", "count": 1})
	d["inventory"].append({"uid": "i99999998", "item_id": "pocao_vida_pequena", "count": 5000})
	d["inventory"].append("lixo")
	var arma: Dictionary = d["equipment"]["arma"]
	arma["enhance"] = 99
	arma["durability"] = 99999
	var b := CharacterData.from_dict(store, d)
	assert_eq(b.inventory.count_of("item_que_nao_existe"), 0)
	assert_eq(b.inventory.count_of("pocao_vida_pequena") >= 1, true)
	for s in b.inventory.slots:
		if s.item_id == "pocao_vida_pequena":
			assert_true(s.count <= 20, "pilha limitada ao max_stack")
	assert_eq(b.equipment.worn["arma"].enhance, 15, "amplificação limitada a +15")
	assert_eq(b.equipment.worn["arma"].durability, 40, "durabilidade limitada ao máximo")


func test_item_in_wrong_slot_is_dropped() -> void:
	var d := _json_roundtrip(_rich_character().to_dict())
	d["equipment"]["peito"] = d["equipment"]["arma"].duplicate()  # arma no slot do peito
	var b := CharacterData.from_dict(store, d)
	assert_false(b.equipment.worn.has("peito") and store.items[b.equipment.worn["peito"].item_id]["slot"] != "peito")


func test_save_and_load_file() -> void:
	var a := _rich_character()
	SaveService.delete(TMP)
	assert_false(SaveService.exists(TMP))
	assert_true(SaveService.save(a, TMP))
	assert_true(SaveService.exists(TMP))
	assert_false(FileAccess.file_exists(TMP + ".tmp"), "arquivo temporário removido")
	var b := SaveService.load_character(store, TMP)
	assert_true(b != null)
	assert_eq(b.gold, 777)
	# Sobrescrever um save existente também funciona.
	a.add_gold(1)
	assert_true(SaveService.save(a, TMP))
	assert_eq(SaveService.load_character(store, TMP).gold, 778)
	SaveService.delete(TMP)


func test_corrupt_file_returns_null() -> void:
	var f := FileAccess.open(TMP, FileAccess.WRITE)
	f.store_string("{ isto não é json")
	f.close()
	assert_true(SaveService.load_character(store, TMP) == null)
	var f2 := FileAccess.open(TMP, FileAccess.WRITE)
	f2.store_string("[1, 2, 3]")
	f2.close()
	assert_true(SaveService.load_character(store, TMP) == null, "JSON que não é dicionário")
	SaveService.delete(TMP)
	assert_true(SaveService.load_character(store, TMP) == null, "sem arquivo")
