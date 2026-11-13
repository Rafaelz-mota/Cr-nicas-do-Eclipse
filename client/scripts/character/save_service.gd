class_name SaveService
extends RefCounted
## Salvamento local (user://), pensado para o celular. Escrita atômica: grava em
## arquivo temporário e só então substitui, para nunca deixar um save corrompido.
##
## ATENÇÃO: salvamento local pode ser editado pelo jogador. É uma etapa
## intermediária; o salvamento autoritativo ficará no servidor.

const DEFAULT_PATH := "user://save_character.json"


static func exists(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func save(character: CharacterData, path: String = DEFAULT_PATH) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(character.to_dict()))
	f.close()
	var dir := DirAccess.open(path.get_base_dir())
	if dir == null:
		return false
	if FileAccess.file_exists(path):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK


## Retorna o personagem salvo ou null (sem arquivo, JSON inválido ou dados inválidos).
static func load_character(p_data: GameDataStore, path: String = DEFAULT_PATH) -> CharacterData:
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	if typeof(json.data) != TYPE_DICTIONARY:
		return null
	return CharacterData.from_dict(p_data, json.data)


static func delete(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.open(path.get_base_dir()).remove(path.get_file())
