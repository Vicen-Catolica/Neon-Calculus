extends Node
## Autoload. Checkpoint do jogador: andar atual, cena, logs de lore lidos, diálogos vistos
## e marcos da história (resgates).
## TDD (integridade do save): grava num arquivo temporário e só então troca pelo
## definitivo, mantendo a versão anterior como backup até a troca terminar.
## Se o jogo fechar no meio, o load ainda encontra o save antigo inteiro.

const SAVE_PATH := "user://save.cfg"
const TMP_PATH := "user://save.cfg.tmp"
const BAK_PATH := "user://save.cfg.bak"
const VERSION := 1


func _ready() -> void:
	# Lore lida no meio de um andar também persiste (não espera o próximo checkpoint).
	GameManager.lore_unlocked.connect(func(_id: String) -> void: _update_progress())
	GameManager.dialogue_seen.connect(func(_id: String) -> void: _update_progress())
	GameManager.flag_set.connect(func(_id: String) -> void: _update_progress())


func has_save() -> bool:
	return not _load_file().is_empty()


## Grava o checkpoint do início de um andar.
func save_checkpoint(floor_number: int, scene_path: String) -> void:
	_write({
		"version": VERSION,
		"floor": floor_number,
		"scene": scene_path,
		"lore_read": GameManager.lore_read.duplicate(),
		"dialogues_seen": GameManager.dialogues_seen.duplicate(),
		"story_flags": GameManager.story_flags.duplicate(),
		"saved_at": Time.get_datetime_string_from_system(),
	})


## Lê o save: {floor, scene, lore_read, ...} ou {} se não houver save válido.
func load_checkpoint() -> Dictionary:
	return _load_file()


## Aplica o save ao GameManager e devolve a cena para carregar ("" se não houver).
func restore() -> String:
	var data := _load_file()
	if data.is_empty():
		return ""
	GameManager.lore_read.clear()
	for id in data.get("lore_read", []):
		GameManager.lore_read.append(String(id))
	GameManager.dialogues_seen.clear()
	for id in data.get("dialogues_seen", []):
		GameManager.dialogues_seen.append(String(id))
	GameManager.story_flags.clear()
	for id in data.get("story_flags", []):
		GameManager.story_flags.append(String(id))
	GameManager.current_floor = int(data.get("floor", 1))
	return String(data.get("scene", ""))


func clear() -> void:
	for p in [SAVE_PATH, TMP_PATH, BAK_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _update_progress() -> void:
	var data := _load_file()
	if data.is_empty():
		return
	data["lore_read"] = GameManager.lore_read.duplicate()
	data["dialogues_seen"] = GameManager.dialogues_seen.duplicate()
	data["story_flags"] = GameManager.story_flags.duplicate()
	_write(data)


func _write(data: Dictionary) -> void:
	var cfg := ConfigFile.new()
	for k in data:
		cfg.set_value("checkpoint", k, data[k])
	if cfg.save(TMP_PATH) != OK:
		push_error("SaveGame: não consegui gravar %s" % TMP_PATH)
		return
	var save_abs := ProjectSettings.globalize_path(SAVE_PATH)
	var bak_abs := ProjectSettings.globalize_path(BAK_PATH)
	# rename não sobrescreve no Windows: tira o save atual do caminho primeiro.
	if FileAccess.file_exists(BAK_PATH):
		DirAccess.remove_absolute(bak_abs)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.rename_absolute(save_abs, bak_abs)
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(TMP_PATH), save_abs) != OK:
		push_error("SaveGame: falha ao trocar o save; mantendo o backup")
		return
	if FileAccess.file_exists(BAK_PATH):
		DirAccess.remove_absolute(bak_abs)


func _load_file() -> Dictionary:
	for p in [SAVE_PATH, BAK_PATH]:
		if not FileAccess.file_exists(p):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(p) != OK or not cfg.has_section("checkpoint"):
			continue
		var data := {}
		for k in cfg.get_section_keys("checkpoint"):
			data[k] = cfg.get_value("checkpoint", k)
		var scene := String(data.get("scene", ""))
		if scene != "" and ResourceLoader.exists(scene):
			return data
	return {}
