class_name HoldingCell
extends Node2D
## Cela com campo de força (Fase 3, Lab 07): prende um NPC resgatável (Dr. Vance).
## Hackear derruba o campo (equação +1 nível, como uma porta reforçada); o NPC
## conversa com Eduardo (diálogo `dialogue_id`) e foge pelo duto de serviço.
## O resgate vira um marco da história (`flag_id`) que vai para o save: ao
## recarregar o andar, a cela já aparece aberta e vazia.
##
## Origem = chão da cela. Filhos: Hackable (no painel) e Prisoner (Sprite2D).

signal rescued

@export var flag_id: String = "vance_rescued"
@export var dialogue_id: String = "rnd_vance"
@export var cell_size: Vector2 = Vector2(150, 176)

const FIELD := Color(1.0, 0.18, 0.3)
const FRAME := Color(0.2, 0.24, 0.3)

var is_open: bool = false
var _prisoner: CanvasItem
## Campo de força desenhado por cima do prisioneiro.
var _field: Node2D


func _ready() -> void:
	add_to_group("holding_cell")
	_prisoner = get_node_or_null("Prisoner") as CanvasItem
	_field = Node2D.new()
	_field.name = "Field"
	add_child(_field)
	_field.draw.connect(_draw_field)
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.kind = Hackable.Kind.DOOR
		h.difficulty_bonus = 1
		h.position = Vector2(cell_size.x / 2.0 + 14.0, -cell_size.y * 0.55)  # painel ao lado
		h.hacked.connect(_on_hacked)
	if GameManager.has_flag(flag_id):
		is_open = true
		if h:
			h.enabled = false
		if _prisoner:
			_prisoner.visible = false
	queue_redraw()


func can_be_hacked() -> bool:
	return not is_open


func _on_hacked() -> void:
	is_open = true
	var h := get_node_or_null("Hackable") as Hackable
	if h:
		h.enabled = false
	queue_redraw()
	_field.queue_redraw()
	# Marca já (vai para o save), antes da conversa: fechar o jogo no meio dela
	# não desfaz o resgate.
	GameManager.set_flag(flag_id)
	rescued.emit()
	if dialogue_id != "" and Dialogue.play_id(dialogue_id):
		await Dialogue.finished
	get_tree().call_group("stealth_hud", "_flash", "PROTOCOLO VANCE ATIVO", Color(0.22, 1.0, 0.08))
	_leave()


## O prisioneiro sai pela lateral e some (duto de serviço).
func _leave() -> void:
	if _prisoner == null or not _prisoner.visible:
		return
	var tw := create_tween()
	tw.tween_property(_prisoner, "position:x", _prisoner.position.x - cell_size.x * 0.9, 1.4)
	tw.parallel().tween_property(_prisoner, "modulate:a", 0.0, 1.4)
	tw.tween_callback(func() -> void: _prisoner.visible = false)


func _process(_delta: float) -> void:
	if not is_open:
		_field.queue_redraw()


func _draw() -> void:
	var w := cell_size.x
	var hgt := cell_size.y
	var r := Rect2(-w / 2.0, -hgt, w, hgt)
	draw_rect(r, Color(0.05, 0.06, 0.08, 0.85))
	# moldura
	draw_rect(Rect2(r.position, Vector2(w, 10)), FRAME)
	draw_rect(Rect2(r.position + Vector2(0, hgt - 6), Vector2(w, 6)), FRAME)
	draw_rect(Rect2(r.position, Vector2(8, hgt)), FRAME)
	draw_rect(Rect2(r.position + Vector2(w - 8, 0), Vector2(8, hgt)), FRAME)
	draw_rect(r, Color(0.05, 0.04, 0.04), false, 2.0)
	# painel de controle ao lado
	var panel := Rect2(w / 2.0 + 6.0, -hgt * 0.55 - 16.0, 16, 32)
	draw_rect(panel, FRAME)
	draw_rect(Rect2(panel.position + Vector2(4, 6), Vector2(8, 6)),
		Color(0.0, 0.94, 1.0) if is_open else FIELD)


func _draw_field() -> void:
	if is_open:
		return
	# campo de força pulsando
	var w := cell_size.x
	var hgt := cell_size.y
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 180.0)
	var inner := Rect2(Vector2(-w / 2.0 + 8.0, -hgt + 10.0), Vector2(w - 16, hgt - 16))
	_field.draw_rect(inner, Color(FIELD, 0.14 * pulse))
	var x := inner.position.x + 6.0
	while x < inner.end.x:
		_field.draw_line(Vector2(x, inner.position.y), Vector2(x, inner.end.y), Color(FIELD, 0.5 * pulse), 2.0)
		x += 18.0
