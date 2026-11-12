extends "res://tools/stage_builder_base.gd"
## Monta a Fase 2 (Setor Industrial e de Manutenção). Uso, na raiz do projeto:
##   godot --headless --path . res://tools/build_industrial_stage.tscn
## Reexecutar sobrescreve a cena gerada (não edite-a à mão; edite este script).
##
## Ainda placeholder (etapa 1 do docs/PLANO_FASE_2.md): chão, paredes, Eduardo e
## a interface, para validar transição e checkpoint. O layout A–E entra na etapa 3.

const OUT_LEVEL := "res://scenes/levels/industrial/industrial_stage2.tscn"
const WIDTH := 2400.0
const FLOOR_Y := 16.0


func out_path() -> String:
	return OUT_LEVEL


func build() -> Node:
	var lvl := _new_level("IndustrialStage2", 2, -32, int(WIDTH) + 32, -700, 300)

	var bg := ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.07, 0.055, 0.05)
	bg.position = Vector2(-1000, -1600)
	bg.size = Vector2(WIDTH + 2000, 2000)
	lvl.add_child(bg)

	var solid := StaticBody2D.new()
	solid.name = "Solid"
	lvl.add_child(solid)
	# chão + paredes das pontas
	for r in [Rect2(-64, FLOOR_Y, WIDTH + 128, 320), Rect2(-64, -900, 64, 1000), Rect2(WIDTH, -900, 64, 1000)]:
		solid.add_child(_rect_shape(r.size, r.get_center()))
		var vis := ColorRect.new()
		vis.color = Color(0.24, 0.17, 0.12)
		vis.position = r.position
		vis.size = r.size
		lvl.add_child(vis)

	var wip := Label.new()
	wip.name = "WipSign"
	wip.text = "SETOR INDUSTRIAL // EM CONSTRUÇÃO"
	wip.position = Vector2(420, -260)
	wip.add_theme_font_size_override("font_size", 28)
	wip.add_theme_color_override("font_color", Color("FF6A1A"))
	lvl.add_child(wip)

	_player_and_ui(lvl, Vector2(96, FLOOR_Y))
	return lvl
