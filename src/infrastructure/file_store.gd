extends RefCounted
## Fichiers du joueur dans user:// : sauvegarde de partie et progression de la campagne.

const SaveCodec = preload("res://src/domain/save_codec.gd")

const SAVE_PATH := "user://sauvegarde.json"
const PROGRESS_PATH := "user://progression.json"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func save_city(c) -> bool:
	return _write(SAVE_PATH, SaveCodec.to_dict(c))


## La cité sauvegardée, ou null.
static func load_city(catalog):
	var data = _read(SAVE_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return SaveCodec.from_dict(catalog, data)


## Nombre de missions débloquées (au moins 1).
static func unlocked_missions() -> int:
	var data = _read(PROGRESS_PATH)
	if typeof(data) != TYPE_DICTIONARY:
		return 1
	return maxi(1, int(data.get("unlocked", 1)))


static func set_unlocked_missions(n: int) -> void:
	_write(PROGRESS_PATH, {"unlocked": n})


static func _write(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))
