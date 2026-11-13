extends CanvasLayer
## Autoload. Menu de pausa (GDD §8): Esc durante uma fase.
## Retomar • Como jogar • Reiniciar andar (volta ao checkpoint) • Menu principal.
## Só abre quando nada mais está pausando o jogo (hack, leitura de lore,
## transição de andar, game over).

const CYAN := Color("00f0ff")
const GREEN := Color("39ff14")
const RED := Color("ff2d55")

var _root: Control
var _buttons: VBoxContainer
var _how_to: HowToPlay


func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		if _how_to == null:
			get_viewport().set_input_as_handled()
			resume()
	elif _can_open():
		get_viewport().set_input_as_handled()
		open()


func _can_open() -> bool:
	var scene := get_tree().current_scene
	if not (scene is Level) or get_tree().paused or LevelTransition.is_busy():
		return false
	if GameManager.state != GameManager.State.PLAYING and GameManager.state != GameManager.State.HACK_VISION:
		return false
	var p := get_tree().get_first_node_in_group("Player")
	return p != null and not p.get("is_dead")


func open() -> void:
	if GameManager.state == GameManager.State.HACK_VISION:
		GameManager.set_state(GameManager.State.PLAYING)
	get_tree().paused = true
	visible = true
	(_buttons.get_child(0) as Button).grab_focus()


func resume() -> void:
	visible = false
	get_tree().paused = false


func _show_how_to() -> void:
	_how_to = HowToPlay.new()
	_how_to.closed.connect(func() -> void:
		_how_to = null
		_root.visible = true
		(_buttons.get_child(1) as Button).grab_focus())
	_root.visible = false
	add_child(_how_to)


func _restart_floor() -> void:
	visible = false
	var scene := SaveGame.restore()
	if scene == "":
		scene = get_tree().current_scene.scene_file_path
	LevelTransition.change_level(scene)


func _main_menu() -> void:
	visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(GameManager.MAIN_MENU_SCENE)


func _build() -> void:
	var font: Font = load("res://assets/fonts/ui_font.tres")
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.012, 0.025, 0.05, 0.95)
	sb.border_color = CYAN
	sb.set_border_width_all(2)
	sb.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = Vector2(700, 300)
	panel.size = Vector2(520, 0)  # altura = conteúdo
	_root.add_child(panel)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 18)
	panel.add_child(vb)
	var title := Label.new()
	title.text = "|| PAUSADO ||"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", CYAN)
	vb.add_child(title)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 14)
	vb.add_child(_buttons)
	for b in [["Retomar infiltração", GREEN, resume], ["Como jogar", CYAN, _show_how_to],
			["Reiniciar andar", CYAN, _restart_floor], ["Menu principal", RED, _main_menu]]:
		_buttons.add_child(_button(font, b[0], b[1], b[2]))


func _button(font: Font, text: String, color: Color, action: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(440, 58)
	btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", color)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)
	var n := StyleBoxFlat.new()
	n.bg_color = Color(0.02, 0.05, 0.09, 0.9)
	n.border_color = Color(color, 0.7)
	n.set_border_width_all(2)
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = Color(color.r * 0.25, color.g * 0.25, color.b * 0.25, 0.95)
	h.border_color = color
	btn.add_theme_stylebox_override("normal", n)
	btn.add_theme_stylebox_override("hover", h)
	btn.add_theme_stylebox_override("focus", h)
	btn.add_theme_stylebox_override("pressed", h)
	btn.pressed.connect(action)
	return btn
