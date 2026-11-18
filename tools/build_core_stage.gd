extends "res://tools/stage_builder_base.gd"
## Monta a Fase 4 (Núcleo Quântico). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_core_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## ESQUELETO (etapa 1 do docs/PLANO_FASE_4.md): só a plataforma de chegada do
## elevador executivo, um corredor e a porta do Domo, para ligar a Fase 3 à
## Fase 4 com transição e checkpoint. O layout A–E entra no greybox (etapa 3).
## Arte provisória: tiles do P&D escurecidos.

const GROUND_TS := "res://assets/tilesets/rnd/rnd_ground.tres"
const OUT_LEVEL := "res://scenes/levels/core/core_stage4.tscn"
## Última fase: a saída (o Domo) vira o Duelo de Paradoxo nas próximas etapas.
const NEXT_STAGE := ""

const GROUND_TINT := Color(0.42, 0.46, 0.56)
const WALL_TINT := Color(0.3, 0.33, 0.42)

const GROUND_RECTS := [
	[-12, 0, 60, 12],
]

const WALL_RECTS := [
	[-12, -16, -7, -1],   # parede esquerda (elevador executivo)
	[-8, -16, 60, -12],   # teto (face de baixo em -368)
	[56, -16, 60, -1],    # parede direita
]


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("CoreStage4", 4, -208, 56 * T, -700, 300)
	_add_background(lvl)
	_terrain_layer(lvl, "Buildings", GROUND_TS, WALL_RECTS, WALL_TINT)
	_terrain_layer(lvl, "Ground", GROUND_TS, GROUND_RECTS, GROUND_TINT)
	_add_exit(lvl)
	_player_and_ui(lvl, Vector2(64, 16))
	return lvl


func _add_background(lvl: Node) -> void:
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.02, 0.025, 0.05)
	bg.position = Vector2(-1200, -1800)
	bg.size = Vector2(4400, 2400)
	lvl.add_child(bg)
	# Linha de luz laranja no teto: território da Axioma.
	var strip := ColorRect.new()
	strip.name = "CoreGlow"
	strip.color = Color(1.0, 0.42, 0.1, 0.35)
	strip.position = Vector2(-208, -368)
	strip.size = Vector2(56 * T + 208, 4)
	lvl.add_child(strip)


func _add_exit(lvl: Node) -> void:
	var exit := _exit(lvl, NEXT_STAGE, Vector2(1680, 16))
	exit.name = "LevelExit"
	var sign := Label.new()
	sign.name = "DomeSign"
	sign.text = "DOMO DE CONTROLE NEURAL\n(Duelo de Paradoxo em construção)"
	sign.position = Vector2(1460, -120)
	sign.add_theme_font_size_override("font_size", 16)
	sign.add_theme_color_override("font_color", Color("FF6A1A"))
	lvl.add_child(sign)
