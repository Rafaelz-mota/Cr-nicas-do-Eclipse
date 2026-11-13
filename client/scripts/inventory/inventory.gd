class_name Inventory
extends RefCounted
## Inventário com capacidade fixa e pilhas. Mutação apenas por estes métodos
## (ponto único para a futura validação no servidor).

var data: GameDataStore
var capacity: int = 30
var slots: Array = []  # Array[ItemInstance]


func _init(p_data: GameDataStore = null) -> void:
	data = p_data
	if data != null:
		capacity = int(data.balance.get("inventory", {}).get("capacity", 30))


## Adiciona itens. Retorna a quantidade que NÃO coube (0 = tudo adicionado).
func add_item(item_id: String, count: int = 1) -> int:
	var def: Dictionary = data.items.get(item_id, {})
	if def.is_empty() or count <= 0:
		return count
	var remaining := count
	var stackable: bool = bool(def.get("stackable", false))
	var max_stack: int = int(def.get("max_stack", 1))
	if stackable:
		for s in slots:
			if remaining <= 0:
				break
			if s.item_id == item_id and s.count < max_stack:
				var put := mini(remaining, max_stack - s.count)
				s.count += put
				remaining -= put
	while remaining > 0 and slots.size() < capacity:
		var put := mini(remaining, max_stack) if stackable else 1
		slots.append(ItemInstance.create(item_id, data, put))
		remaining -= put
	return remaining


func add_instance(inst: ItemInstance) -> bool:
	if slots.size() >= capacity:
		return false
	slots.append(inst)
	return true


func count_of(item_id: String) -> int:
	var total := 0
	for s in slots:
		if s.item_id == item_id:
			total += s.count
	return total


func remove_item(item_id: String, count: int = 1) -> bool:
	if count_of(item_id) < count:
		return false
	var remaining := count
	for i in range(slots.size() - 1, -1, -1):
		if remaining <= 0:
			break
		var s: ItemInstance = slots[i]
		if s.item_id != item_id:
			continue
		var take := mini(remaining, s.count)
		s.count -= take
		remaining -= take
		if s.count <= 0:
			slots.remove_at(i)
	return true


func find_uid(uid: String) -> ItemInstance:
	for s in slots:
		if s.uid == uid:
			return s
	return null


## Remove e devolve a instância inteira (usado ao equipar).
func take_uid(uid: String) -> ItemInstance:
	for i in range(slots.size()):
		if slots[i].uid == uid:
			var inst: ItemInstance = slots[i]
			slots.remove_at(i)
			return inst
	return null


func is_full() -> bool:
	return slots.size() >= capacity
