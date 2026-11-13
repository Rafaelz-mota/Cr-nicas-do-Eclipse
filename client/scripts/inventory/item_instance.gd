class_name ItemInstance
extends RefCounted
## Uma instância concreta de item (pilha ou equipamento com estado próprio).
## O uid é único; o servidor autoritativo deve ser quem emite uids reais
## (proteção contra duplicação).

static var _uid_counter: int = 0

var uid: String = ""
var item_id: String = ""
var count: int = 1
var enhance: int = 0
var durability: int = 0
var enchants: Array = []  # reservado: encantamentos e pedras de atributos


static func create(p_item_id: String, data: GameDataStore, p_count: int = 1) -> ItemInstance:
	var inst := ItemInstance.new()
	_uid_counter += 1
	inst.uid = "i%08d" % _uid_counter
	inst.item_id = p_item_id
	inst.count = p_count
	var def: Dictionary = data.items.get(p_item_id, {})
	inst.durability = int(def.get("durability_max", 0))
	return inst


func to_dict() -> Dictionary:
	return {"uid": uid, "item_id": item_id, "count": count, "enhance": enhance, "durability": durability, "enchants": enchants.duplicate(true)}


static func from_dict(d: Dictionary) -> ItemInstance:
	var inst := ItemInstance.new()
	inst.uid = str(d.get("uid", ""))
	inst.item_id = str(d.get("item_id", ""))
	inst.count = int(d.get("count", 1))
	inst.enhance = int(d.get("enhance", 0))
	inst.durability = int(d.get("durability", 0))
	inst.enchants = (d.get("enchants", []) as Array).duplicate(true)
	return inst
