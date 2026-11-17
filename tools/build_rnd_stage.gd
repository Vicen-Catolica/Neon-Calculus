extends "res://tools/stage_builder_base.gd"
## Monta a Fase 3 (Setor de Administração e P&D). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_rnd_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## ESQUELETO (etapa 1 do docs/PLANO_FASE_3.md): só a doca de chegada, um
## corredor e a saída, para ligar a Fase 2 à Fase 3 com transição e checkpoint.
## O layout A–E entra no greybox (etapa 3). Arte provisória: tiles industriais
## clareados e tingidos de azul-gelo.

const GROUND_TS := "res://assets/tilesets/industrial/industrial_ground.tres"
const OUT_LEVEL := "res://scenes/levels/rnd/rnd_stage3.tscn"
## Fase 4 (Núcleo Quântico) ainda não existe: a saída fica desligada até lá.
const NEXT_STAGE := ""

const GROUND_TINT := Color(0.78, 0.84, 0.92)
const WALL_TINT := Color(0.55, 0.6, 0.68)

const GROUND_RECTS := [
	[-12, 0, 60, 12],
]

const WALL_RECTS := [
	[-12, -16, -7, -1],   # parede esquerda (doca do elevador de carga)
	[-8, -16, 60, -12],   # teto (face de baixo em -368)
	[56, -16, 60, -1],    # parede direita
]


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("RndStage3", 3, -208, 56 * T, -700, 300)
	_add_background(lvl)
	_terrain_layer(lvl, "Buildings", GROUND_TS, WALL_RECTS, WALL_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, GROUND_RECTS, GROUND_TINT)
	_add_exit(lvl)
	_player_and_ui(lvl, Vector2(64, 16))
	return lvl


func _add_background(lvl: Node) -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.11, 0.14, 0.19)
	bg.position = Vector2(-1200, -1800)
	bg.size = Vector2(4400, 2400)
	lvl.add_child(bg)
	# Faixa de luz no teto: o andar corporativo é claro e vigiado.
	var strip := ColorRect.new()
	strip.name = "CeilingLight"
	strip.color = Color(0.75, 0.95, 1.0, 0.35)
	strip.position = Vector2(-208, -368)
	strip.size = Vector2(56 * T + 208, 6)
	lvl.add_child(strip)


func _add_exit(lvl: Node) -> void:
	var exit := _exit(lvl, NEXT_STAGE, Vector2(1680, 16))
	exit.name = "LevelExit"
	var sign := Label.new()
	sign.name = "ElevatorSign"
	sign.text = "ELEVADOR EXECUTIVO  ->  NÚCLEO\n(fase 4 em construção)"
	sign.position = Vector2(1520, -120)
	sign.add_theme_font_size_override("font_size", 16)
	sign.add_theme_color_override("font_color", Color("00F0FF"))
	lvl.add_child(sign)
