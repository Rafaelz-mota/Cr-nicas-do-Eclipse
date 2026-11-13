class_name GameDataStore
extends RefCounted
## Carrega e valida todos os dados do jogo (JSON em res://data/).
## Lógica pura, sem dependência de nós: pode ser reutilizada em testes e
## espelhada no servidor (as regras ficam nos dados, não no código).

const DATA_DIR := "res://data/"

var balance: Dictionary = {}
var rarities: Dictionary = {}
var classes: Dictionary = {}
var clans: Dictionary = {}
var skills: Dictionary = {}
var items: Dictionary = {}
var monsters: Dictionary = {}
var npcs: Dictionary = {}
var quests: Dictionary = {}
var load_errors: Array[String] = []


static func load_default() -> GameDataStore:
	var store := GameDataStore.new()
	store.load_all()
	return store


func load_all() -> void:
	load_errors.clear()
	balance = _read_json("balance.json")
	rarities = _index(_read_json("rarities.json"), "rarities")
	classes = _index(_read_json("classes.json"), "classes")
	clans = _index(_read_json("clans.json"), "clans")
	skills = _index(_read_json("skills.json"), "skills")
	items = _index(_read_json("items.json"), "items")
	monsters = _index(_read_json("monsters.json"), "monsters")
	npcs = _index(_read_json("npcs.json"), "npcs")
	quests = _index(_read_json("quests.json"), "quests")


func _read_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + file_name
	if not FileAccess.file_exists(path):
		load_errors.append("Arquivo de dados ausente: %s" % path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		load_errors.append("JSON inválido: %s" % path)
		return {}
	return parsed


func _index(root: Dictionary, key: String) -> Dictionary:
	var out := {}
	var list: Variant = root.get(key, [])
	if typeof(list) != TYPE_ARRAY:
		load_errors.append("Chave '%s' ausente ou não é lista" % key)
		return out
	for entry in list:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			load_errors.append("Entrada sem 'id' em '%s'" % key)
			continue
		var id: String = entry["id"]
		if out.has(id):
			load_errors.append("ID duplicado em '%s': %s" % [key, id])
		out[id] = entry
	return out


## Verificações de integridade entre os arquivos. Retorna lista de erros (vazia = ok).
func validate() -> Array[String]:
	var errs: Array[String] = []
	errs.append_array(load_errors)

	# Raridades: precisam ser exatamente as sete, na ordem.
	for rid in Rarity.ORDER:
		if not rarities.has(rid):
			errs.append("Raridade ausente: %s" % rid)
	if rarities.size() != Rarity.ORDER.size():
		errs.append("Esperadas %d raridades, encontradas %d" % [Rarity.ORDER.size(), rarities.size()])

	# Amplificação +0..+15.
	var enh: Dictionary = balance.get("enhancement", {})
	var table: Array = enh.get("table", [])
	if int(enh.get("max_level", 0)) != 15 or table.size() != 15:
		errs.append("Tabela de amplificação deve cobrir +1..+15")
	if enh.get("on_failure", "") != "none":
		errs.append("Falha de amplificação não deve destruir equipamento (on_failure deve ser 'none')")

	for cid in classes:
		var cls: Dictionary = classes[cid]
		for attr in CombatStats.ATTRIBUTES:
			if not cls.get("base_attributes", {}).has(attr):
				errs.append("Classe %s sem atributo base %s" % [cid, attr])
		for sid in cls.get("skills", []):
			if not skills.has(sid):
				errs.append("Classe %s referencia habilidade inexistente %s" % [cid, sid])
		for iid in cls.get("starter_items", []):
			if not items.has(iid):
				errs.append("Classe %s referencia item inicial inexistente %s" % [cid, iid])

	for kid in clans:
		for sid in clans[kid].get("techniques", []):
			if not skills.has(sid):
				errs.append("Clã %s referencia técnica inexistente %s" % [kid, sid])

	for sid in skills:
		var sk: Dictionary = skills[sid]
		var otype: String = sk.get("owner_type", "")
		var owner: String = sk.get("owner", "")
		if otype == "class" and not classes.has(owner):
			errs.append("Habilidade %s com classe dona inexistente %s" % [sid, owner])
		elif otype == "clan" and not clans.has(owner):
			errs.append("Habilidade %s com clã dono inexistente %s" % [sid, owner])
		elif otype != "class" and otype != "clan":
			errs.append("Habilidade %s com owner_type inválido" % sid)

	for iid in items:
		if not rarities.has(items[iid].get("rarity", "")):
			errs.append("Item %s com raridade inválida" % iid)

	for mid in monsters:
		var m: Dictionary = monsters[mid]
		for drop in m.get("loot", []):
			if not items.has(drop.get("item", "")):
				errs.append("Monstro %s com loot inexistente %s" % [mid, drop.get("item", "")])

	for nid in npcs:
		for qid in npcs[nid].get("quests", []):
			if not quests.has(qid):
				errs.append("NPC %s referencia missão inexistente %s" % [nid, qid])

	for qid in quests:
		var q: Dictionary = quests[qid]
		if not npcs.has(q.get("giver", "")):
			errs.append("Missão %s com NPC inexistente %s" % [qid, q.get("giver", "")])
		var req: String = q.get("requires_quest", "")
		if req != "" and not quests.has(req):
			errs.append("Missão %s requer missão inexistente %s" % [qid, req])
		for obj in q.get("objectives", []):
			if obj.get("type", "") == "kill" and not monsters.has(obj.get("target", "")):
				errs.append("Missão %s com alvo inexistente %s" % [qid, obj.get("target", "")])
		for it in q.get("rewards", {}).get("items", []):
			if not items.has(it.get("id", "")):
				errs.append("Missão %s com recompensa inexistente %s" % [qid, it.get("id", "")])
	return errs
