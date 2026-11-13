extends TestCase
## Inventário, equipamento, durabilidade, amplificação e serialização.

var store: GameDataStore = GameDataStore.load_default()


func _rng(seed_value: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	return r


func test_stacking_and_capacity() -> void:
	var inv := Inventory.new(store)
	assert_eq(inv.add_item("pocao_vida_pequena", 25), 0)
	assert_eq(inv.slots.size(), 2, "20 + 5")
	assert_eq(inv.count_of("pocao_vida_pequena"), 25)
	assert_true(inv.remove_item("pocao_vida_pequena", 22))
	assert_eq(inv.count_of("pocao_vida_pequena"), 3)
	assert_false(inv.remove_item("pocao_vida_pequena", 4), "não remove mais do que existe")
	assert_eq(inv.count_of("pocao_vida_pequena"), 3, "falha não altera estado")


func test_inventory_full_returns_overflow() -> void:
	var inv := Inventory.new(store)
	inv.capacity = 2
	assert_eq(inv.add_item("espada_treino", 3), 1, "só 2 cabem (não empilhável)")
	assert_true(inv.is_full())


func test_unknown_item_rejected() -> void:
	var inv := Inventory.new(store)
	assert_eq(inv.add_item("item_que_nao_existe", 1), 1)
	assert_eq(inv.slots.size(), 0)


func test_unique_uids() -> void:
	var inv := Inventory.new(store)
	inv.add_item("espada_treino", 5)
	var seen := {}
	for s in inv.slots:
		assert_false(seen.has(s.uid), "uid duplicado")
		seen[s.uid] = true


func test_equip_swap_and_restrictions() -> void:
	var ch := CharacterData.create_new(store, "T", "vanguarda", "veu_cinzento")
	assert_true(ch.equipment.worn.has("arma"), "arma inicial equipada")
	assert_true(ch.equipment.worn.has("peito"))
	# Arma de outro tipo não pode.
	ch.inventory.add_item("cajado_aprendiz", 1)
	var staff: ItemInstance = ch.inventory.slots[ch.inventory.slots.size() - 1]
	var bad := ch.equip_item(staff.uid)
	assert_false(bad["ok"])
	assert_eq(bad["reason"], "tipo_de_arma")
	# Botas exigem nível 2.
	ch.inventory.add_item("botas_viajante", 1)
	var boots: ItemInstance = ch.inventory.slots[ch.inventory.slots.size() - 1]
	assert_eq(ch.equip_item(boots.uid)["reason"], "nivel")
	ch.add_xp(100)
	assert_true(ch.equip_item(boots.uid)["ok"])
	assert_true(ch.equipment.worn.has("botas"))
	assert_true(ch.inventory.find_uid(boots.uid) == null, "saiu do inventário")


func test_equipment_adds_bonus_and_enhancement_scales_it() -> void:
	var ch := CharacterData.create_new(store, "T", "vanguarda", "veu_cinzento")
	var base_atk: float = ch.derived_stats()["phys_attack"]
	var sword: ItemInstance = ch.equipment.worn["arma"]
	sword.enhance = 10
	var boosted: float = ch.derived_stats()["phys_attack"]
	assert_approx(boosted - base_atk, 6.0 * 10 * 0.06, 0.001, "+10 = +60% do ataque base da arma")


func test_broken_item_gives_no_bonus() -> void:
	var ch := CharacterData.create_new(store, "T", "vanguarda", "veu_cinzento")
	var with_sword: float = ch.derived_stats()["phys_attack"]
	ch.equipment.worn["arma"].durability = 0
	var broken: float = ch.derived_stats()["phys_attack"]
	assert_approx(with_sword - broken, 6.0, 0.001)


func test_wear_and_repair_cost() -> void:
	var ch := CharacterData.create_new(store, "T", "vanguarda", "veu_cinzento")
	ch.equipment.wear(5, store)
	var cost := ch.equipment.repair_cost(store)
	assert_eq(cost, 5 * 2 * 2, "2 peças x 5 pontos x 2 gold")
	assert_false(ch.repair_equipment(), "sem gold")
	ch.add_gold(cost)
	assert_true(ch.repair_equipment())
	assert_eq(ch.equipment.repair_cost(store), 0)
	assert_eq(ch.gold, 0)


func test_enhancement_never_destroys_and_charges_gold() -> void:
	var ch := CharacterData.create_new(store, "T", "vanguarda", "veu_cinzento")
	var sword: ItemInstance = ch.equipment.worn["arma"]
	assert_false(ch.enhance_item(sword.uid, _rng())["ok"], "sem gold")
	ch.add_gold(1000000)
	var rng := _rng(1)
	var prev := sword.enhance
	for i in range(200):
		var gold_before := ch.gold
		var r := ch.enhance_item(sword.uid, rng)
		if not r["ok"]:
			assert_eq(r["reason"], "nivel_maximo")
			break
		assert_true(sword.enhance >= prev, "nunca regride nem some")
		assert_true(ch.gold < gold_before, "custo cobrado mesmo na falha")
		prev = sword.enhance
	assert_eq(sword.enhance, 15, "chega ao máximo +15")
	assert_true(ch.equipment.worn.has("arma"), "item continua equipado")


func test_item_serialization_roundtrip() -> void:
	var inst := ItemInstance.create("espada_treino", store)
	inst.enhance = 7
	inst.durability = 12
	var copy := ItemInstance.from_dict(inst.to_dict())
	assert_eq(copy.uid, inst.uid)
	assert_eq(copy.enhance, 7)
	assert_eq(copy.durability, 12)


func test_consumable_use() -> void:
	var ch := CharacterData.create_new(store, "T", "vanguarda", "veu_cinzento")
	var potion := ch.inventory.slots.filter(func(s): return s.item_id == "pocao_vida_pequena")[0] as ItemInstance
	var effect := ch.use_consumable(potion.uid)
	assert_eq(int(effect["heal"]), 60)
	assert_eq(ch.inventory.count_of("pocao_vida_pequena"), 2)
	assert_true(ch.use_consumable("uid_falso").is_empty())
