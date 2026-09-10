class_name HUD
extends CanvasLayer

@onready var margin_container: MarginContainer = %MarginContainer
@onready var defense_bar: ProgressBar = %DefenseBar
@onready var label_title: Label = %LabelTitle
@onready var label_status: Label = %LabelStatus
@onready var label_values: Label = %LabelValues

var tween: Tween
var original_margin_pos: Vector2

func _ready() -> void:
	# Registra no grupo global para ocultar/exibir sob demanda
	add_to_group("hud")

	if margin_container:
		original_margin_pos = margin_container.position

	_setup_cyberpunk_styles()
	
	await get_tree().process_frame
	var player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.defense_changed.connect(_on_defense_changed)
		_on_defense_changed(player.current_defense, player.max_defense, false)

func hide_hud() -> void:
	visible = false

func show_hud() -> void:
	visible = true

func _setup_cyberpunk_styles() -> void:
	if margin_container:
		margin_container.custom_minimum_size = Vector2(300, 0)

	defense_bar.custom_minimum_size = Vector2(300, 16)
	defense_bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	defense_bar.show_percentage = false

	if label_title:
		label_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	if label_status:
		label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color("#06080e")
	bg_style.border_color = Color("#00f0ff", 0.6)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(0)
	bg_style.content_margin_left = 2
	bg_style.content_margin_right = 2
	bg_style.content_margin_top = 2
	bg_style.content_margin_bottom = 2

	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color("#00f0ff")
	fill_style.set_corner_radius_all(0)

	defense_bar.add_theme_stylebox_override("background", bg_style)
	defense_bar.add_theme_stylebox_override("fill", fill_style)

	if ResourceLoader.exists("res://assets/fonts/Orbitron-Bold.ttf"):
		var custom_font = load("res://assets/fonts/Orbitron-Bold.ttf")
		label_title.add_theme_font_override("font", custom_font)
		label_status.add_theme_font_override("font", custom_font)
		label_values.add_theme_font_override("font", custom_font)

	label_title.add_theme_color_override("font_color", Color("#00f0ff"))
	label_title.add_theme_font_size_override("font_size", 11)

	label_status.add_theme_font_size_override("font_size", 10)
	
	label_values.add_theme_color_override("font_color", Color("#8a93b0"))
	label_values.add_theme_font_size_override("font_size", 10)

func _on_defense_changed(current: float, max_val: float, animate: bool = true) -> void:
	defense_bar.max_value = max_val
	var ratio = current / max_val if max_val > 0 else 0.0
	var target_color = _get_status_color(ratio)

	if label_values:
		label_values.text = "%d / %d DEF" % [int(current), int(max_val)]

	_update_status_label(ratio, target_color)

	if animate:
		if current < defense_bar.value:
			_shake_hud()

		if tween and tween.is_running():
			tween.kill()

		tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(defense_bar, "value", current, 0.2)
		
		var fill = defense_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			tween.tween_property(fill, "bg_color", target_color, 0.2)
	else:
		defense_bar.value = current
		var fill = defense_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if fill:
			fill.bg_color = target_color

func _get_status_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color("#00f0ff")
	elif ratio > 0.25:
		return Color("#ffaa00")
	else:
		return Color("#ff0055")

func _update_status_label(ratio: float, status_color: Color) -> void:
	if not label_status:
		return

	label_status.add_theme_color_override("font_color", status_color)
	if ratio > 0.5:
		label_status.text = "[SISTEMA OK]"
	elif ratio > 0.25:
		label_status.text = "[ALERTA]"
	else:
		label_status.text = "[CRÍTICO]"

func _shake_hud() -> void:
	if not margin_container:
		return

	var shake_tween = create_tween()
	var offset1 = Vector2(randf_range(-3, 3), randf_range(-3, 3))
	var offset2 = Vector2(randf_range(-2, 2), randf_range(-2, 2))

	shake_tween.tween_property(margin_container, "position", original_margin_pos + offset1, 0.04)
	shake_tween.tween_property(margin_container, "position", original_margin_pos + offset2, 0.04)
	shake_tween.tween_property(margin_container, "position", original_margin_pos, 0.04)
