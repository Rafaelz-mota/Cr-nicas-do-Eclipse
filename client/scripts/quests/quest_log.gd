class_name QuestLog
extends RefCounted
## Diário de missões orientado a dados (quests.json). Progresso por eventos
## ("kill", futuramente "collect", "talk"...). Cadeias via requires_quest.

var data: GameDataStore
var active: Dictionary = {}     # quest_id -> {"progress": Array[int]}
var completed: Dictionary = {}  # quest_id -> true


func _init(p_data: GameDataStore = null) -> void:
	data = p_data


## "" se pode aceitar; caso contrário o motivo.
func can_accept(quest_id: String, char_level: int) -> String:
	var q: Dictionary = data.quests.get(quest_id, {})
	if q.is_empty():
		return "inexistente"
	if completed.has(quest_id):
		return "concluida"
	if active.has(quest_id):
		return "ativa"
	if char_level < int(q.get("requires_level", 1)):
		return "nivel"
	var req: String = q.get("requires_quest", "")
	if req != "" and not completed.has(req):
		return "pre_requisito"
	return ""


func accept(quest_id: String, char_level: int) -> bool:
	if can_accept(quest_id, char_level) != "":
		return false
	var count: int = (data.quests[quest_id].get("objectives", []) as Array).size()
	var progress: Array = []
	progress.resize(count)
	progress.fill(0)
	active[quest_id] = {"progress": progress}
	return true


## Registra um evento. Retorna ids de missões cujo progresso mudou.
func on_event(type: String, target: String, amount: int = 1) -> Array:
	var changed: Array = []
	for qid in active:
		var objectives: Array = data.quests[qid].get("objectives", [])
		var progress: Array = active[qid]["progress"]
		var touched := false
		for i in range(objectives.size()):
			var obj: Dictionary = objectives[i]
			if obj.get("type", "") == type and obj.get("target", "") == target:
				var need: int = int(obj.get("count", 1))
				if progress[i] < need:
					progress[i] = mini(need, progress[i] + amount)
					touched = true
		if touched:
			changed.append(qid)
	return changed


func is_ready(quest_id: String) -> bool:
	if not active.has(quest_id):
		return false
	var objectives: Array = data.quests[quest_id].get("objectives", [])
	var progress: Array = active[quest_id]["progress"]
	for i in range(objectives.size()):
		if progress[i] < int(objectives[i].get("count", 1)):
			return false
	return true


## Conclui a missão e devolve as recompensas (o chamador as concede).
func turn_in(quest_id: String) -> Dictionary:
	if not is_ready(quest_id):
		return {}
	active.erase(quest_id)
	completed[quest_id] = true
	return (data.quests[quest_id].get("rewards", {}) as Dictionary).duplicate(true)


func progress_text(quest_id: String) -> String:
	var q: Dictionary = data.quests.get(quest_id, {})
	if q.is_empty() or not active.has(quest_id):
		return ""
	var parts: PackedStringArray = []
	var objectives: Array = q.get("objectives", [])
	var progress: Array = active[quest_id]["progress"]
	for i in range(objectives.size()):
		var obj: Dictionary = objectives[i]
		var tname: String = data.monsters.get(obj.get("target", ""), {}).get("name", obj.get("target", ""))
		parts.append("%s %d/%d" % [tname, progress[i], int(obj.get("count", 1))])
	return "%s — %s" % [q.get("title", quest_id), ", ".join(parts)]


func available_for_npc(npc_id: String, char_level: int) -> Array:
	var out: Array = []
	for qid in data.npcs.get(npc_id, {}).get("quests", []):
		if can_accept(qid, char_level) == "":
			out.append(qid)
	return out


func ready_for_npc(npc_id: String) -> Array:
	var out: Array = []
	for qid in data.npcs.get(npc_id, {}).get("quests", []):
		if is_ready(qid):
			out.append(qid)
	return out
