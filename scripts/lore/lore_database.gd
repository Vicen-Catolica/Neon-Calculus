class_name LoreDatabase
extends RefCounted
## Carrega os logs de lore (LogEntry) dos arquivos JSON em res://data/lore/.
## Cada entrada: { source, title, author, text }.

const LORE_DIR := "res://data/lore/"

static var _cache: Dictionary = {}


static func get_entry(entry_id: String) -> Dictionary:
	if _cache.is_empty():
		_load_all()
	return _cache.get(entry_id, {})


static func _load_all() -> void:
	var dir := DirAccess.open(LORE_DIR)
	if dir == null:
		push_warning("LoreDatabase: pasta %s não encontrada" % LORE_DIR)
		return
	for file in dir.get_files():
		if not file.ends_with(".json"):
			continue
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(LORE_DIR + file))
		if parsed is Dictionary:
			_cache.merge(parsed)
		else:
			push_warning("LoreDatabase: JSON inválido em %s" % file)
