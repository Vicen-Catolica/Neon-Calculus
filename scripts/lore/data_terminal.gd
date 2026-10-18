class_name DataTerminal
extends Area2D
## Terminal de dados (lore). Com o jogador perto, `interact_world` abre o leitor.
## Origem = base do terminal (chão).

@export var entry_id: String = ""

var _player_near: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	add_to_group("data_terminal")
	body_entered.connect(func(b): if b.is_in_group("Player"): _player_near = true)
	body_exited.connect(func(b): if b.is_in_group("Player"): _player_near = false)
	sprite.play(&"idle")


func is_player_near() -> bool:
	return _player_near


func get_interaction_hint() -> String:
	var read := entry_id in GameManager.lore_read
	return "[F] LER TERMINAL" + ("  (LIDO)" if read else "")


func _unhandled_input(event: InputEvent) -> void:
	if not _player_near or GameManager.state != GameManager.State.PLAYING:
		return
	if event.is_action_pressed("interact_world"):
		var player := get_tree().get_first_node_in_group("Player")
		if player and player.has_method("is_hidden") and player.is_hidden():
			return
		get_viewport().set_input_as_handled()
		open()


func open() -> void:
	var entry := LoreDatabase.get_entry(entry_id)
	if entry.is_empty():
		push_warning("DataTerminal: entrada '%s' não existe" % entry_id)
		return
	sprite.play(&"reading")
	GameManager.mark_lore_read(entry_id)
	var reader := get_tree().get_first_node_in_group("lore_reader")
	if reader:
		reader.show_entry(entry)
		if not reader.closed.is_connected(_on_reader_closed):
			reader.closed.connect(_on_reader_closed, CONNECT_ONE_SHOT)


func _on_reader_closed() -> void:
	sprite.play(&"idle")
