class_name AxiomaCore
extends Node2D
## O núcleo da Axioma no Domo de Controle Neural: um icosaedro laranja girando
## (o mesmo da tela de transição, GDD §8), com brilho pulsante. `damage_level`
## (0–3) sobe a cada nó de vigilância derrubado: o núcleo treme, perde arestas
## e ganha rachaduras ciano. `charge()` acende antes de um ataque; `collapse()`
## é o Paradoxo inserido (apaga tudo).

const ORANGE := Color(1.0, 0.42, 0.1)
const CYAN := Color(0.0, 0.94, 1.0)
const PHI := 1.618034

@export var radius: float = 120.0

var damage_level: int = 0
var collapsed: bool = false
## Aberto depois dos 3 nós: hackear o núcleo é o Paradoxo final.
var paradox_open: bool = false
var _angle: float = 0.0
var _charge: float = 0.0
var _collapse_t: float = -1.0
var _verts: Array[Vector3] = []
var _edges: Array[Vector2i] = []


func _ready() -> void:
	add_to_group("axioma_core")
	z_index = 5
	for a in [-1.0, 1.0]:
		for b in [-PHI, PHI]:
			_verts.append(Vector3(0, a, b))
			_verts.append(Vector3(a, b, 0))
			_verts.append(Vector3(b, 0, a))
	for i in _verts.size():
		for j in range(i + 1, _verts.size()):
			if absf(_verts[i].distance_to(_verts[j]) - 2.0) < 0.01:
				_edges.append(Vector2i(i, j))


func can_be_hacked() -> bool:
	return paradox_open and not collapsed


## Acende antes de um ataque (telegrafia).
func charge(seconds: float = 0.8) -> void:
	_charge = seconds


func set_damage(level: int) -> void:
	damage_level = clampi(level, 0, 3)


func collapse() -> void:
	collapsed = true
	_collapse_t = 0.0


func _process(delta: float) -> void:
	var speed := 0.6 + 0.35 * damage_level
	if collapsed:
		_collapse_t += delta
		speed = maxf(0.0, 2.5 - _collapse_t)
	_angle += delta * speed
	_charge = maxf(_charge - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	var basis := Basis(Vector3.UP, _angle * 0.9) * Basis(Vector3.RIGHT, 0.45 + sin(_angle * 0.5) * 0.2)
	var k := radius / sqrt(1.0 + PHI * PHI)
	var shake := Vector2.ZERO
	if damage_level > 0 and not collapsed:
		shake = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * damage_level * 1.5
	var pts: Array[Vector2] = []
	for v in _verts:
		var r := basis * v
		pts.append(Vector2(r.x, r.y) * k + shake)
	var fade := 1.0
	if collapsed:
		fade = clampf(1.0 - _collapse_t / 3.0, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 300.0)
	var glow := 0.08 + 0.06 * pulse + (0.25 if _charge > 0.0 else 0.0)
	draw_circle(Vector2.ZERO, radius * 1.25, Color(ORANGE, glow * fade))
	for i in _edges.size():
		var e := _edges[i]
		# Arestas "quebradas" somem conforme o dano.
		if damage_level > 0 and i % (6 - damage_level) == 0 and not collapsed:
			draw_line(pts[e.x], pts[e.y], Color(CYAN, 0.6), 1.0)
			continue
		draw_line(pts[e.x], pts[e.y], Color(ORANGE, 0.16 * fade), 9.0)
		draw_line(pts[e.x], pts[e.y], Color(ORANGE, fade), 3.0)
	for p in pts:
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), Color(1, 0.85, 0.6, fade))
	if paradox_open and not collapsed:
		# Núcleo exposto: anel ciano pulsando (o alvo do Paradoxo).
		draw_arc(Vector2.ZERO, radius * 1.1, 0.0, TAU, 48, Color(CYAN, 0.4 + 0.4 * pulse), 3.0)
