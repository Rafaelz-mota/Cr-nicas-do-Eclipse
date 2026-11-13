class_name Rarity
extends RefCounted
## As sete raridades de equipamento, da menor para a maior.

const ORDER: Array[String] = ["comum", "incomum", "raro", "epico", "lendario", "mitico", "unico"]


static func index_of(id: String) -> int:
	return ORDER.find(id)


static func is_valid(id: String) -> bool:
	return ORDER.has(id)
