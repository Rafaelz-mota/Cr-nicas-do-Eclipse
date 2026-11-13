extends TestCase
## Integridade dos arquivos de dados (res://data/*.json).


func test_data_loads_and_validates() -> void:
	var store := GameDataStore.load_default()
	assert_empty(store.validate(), "erros de validação de dados:")


func test_seven_rarities_in_order() -> void:
	var store := GameDataStore.load_default()
	assert_eq(store.rarities.size(), 7, "quantidade de raridades")
	for i in range(Rarity.ORDER.size()):
		assert_eq(int(store.rarities[Rarity.ORDER[i]]["order"]), i, "ordem da raridade " + Rarity.ORDER[i])


func test_max_level_is_50() -> void:
	var store := GameDataStore.load_default()
	assert_eq(int(store.balance["max_level"]), 50)


func test_enhancement_table_covers_plus1_to_plus15() -> void:
	var store := GameDataStore.load_default()
	var table: Array = store.balance["enhancement"]["table"]
	assert_eq(table.size(), 15)
	for i in range(15):
		assert_eq(int(table[i]["to"]), i + 1)
	assert_eq(store.balance["enhancement"]["on_failure"], "none", "falha não destrói")


func test_every_class_has_skills_and_starter_items() -> void:
	var store := GameDataStore.load_default()
	assert_true(store.classes.size() >= 4)
	for cid in store.classes:
		assert_true((store.classes[cid]["skills"] as Array).size() >= 2, "habilidades de " + cid)
