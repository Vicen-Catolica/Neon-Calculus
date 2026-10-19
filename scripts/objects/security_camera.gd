class_name SecurityCamera
extends Node2D
## Câmera de vigilância (parede ou dome de teto). Os sprites não giram: a câmera
## mantém um ângulo de mira e escolhe a coluna do spritesheet mais próxima
## (angles.json). Varre entre dois limites; ao ver o jogador, segue-o e, após um
## tempo de exposição, dispara o alarme. Hackeada, desliga por `disabled_time`.

enum Model { WALL, DOME }
enum Mode { SWEEP, ALERT, HACKED, DISABLED }

@export var model: Model = Model.WALL
## Câmera de parede na parede da direita (olhando para a esquerda).
@export var facing_left: bool = false
@export_range(0.0, 180.0) var sweep_min_deg: float = 20.0
@export_range(0.0, 180.0) var sweep_max_deg: float = 60.0
@export var sweep_speed: float = 18.0
@export var sweep_pause: float = 1.2
@export var track_speed: float = 70.0
@export var vision_range: float = 380.0
@export var fov_deg: float = 34.0
## Segundos vendo o jogador até disparar o alarme (barra de detecção abaixo da câmera).
@export var exposure_to_alarm: float = 1.5
@export var disabled_time: float = 8.0
@export var world_mask: int = 1

const SHEETS := {
	Model.WALL: "res://assets/objects/camera_wall/",
	Model.DOME: "res://assets/objects/camera_dome/",
}

var mode: Mode = Mode.SWEEP
var aim_deg: float = 40.0

var _textures: Dictionary = {}
var _aims: Array[float] = []
var _lens: Array[Vector2] = []
var _frame_size: Vector2 = Vector2(80, 80)
var _sweep_dir: float = 1.0
var _pause: float = 0.0
var _exposure: float = 0.0
var _lost_timer: float = 0.0
var _mode_timer: float = 0.0
var _blink: float = 0.0
var _alarm_cooldown: float = 0.0
var _cone: PackedVector2Array = PackedVector2Array()

@onready var sprite: Sprite2D = $Sprite
@onready var hackable: Hackable = $Hackable


func _ready() -> void:
	add_to_group("security_camera")
	_load_model()
	aim_deg = (sweep_min_deg + sweep_max_deg) * 0.5
	if facing_left:
		aim_deg = 180.0 - aim_deg
	hackable.kind = Hackable.Kind.CAMERA
	hackable.hacked.connect(_on_hacked)
	_apply_frame()


func _load_model() -> void:
	var base: String = SHEETS[model]
	for st in ["normal", "alert", "hacked", "disabled"]:
		_textures[st] = load(base + st + "_sheet.png")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(base + "angles.json"))
	_frame_size = Vector2(meta["frame_size"][0], meta["frame_size"][1])
	for col in meta["columns"]:
		_aims.append(float(col["aim_deg"]))
		_lens.append(Vector2(col["lens_point"][0], col["lens_point"][1]))
	sprite.texture = _textures["normal"]
	sprite.hframes = _aims.size()
	sprite.vframes = 2
	sprite.flip_h = facing_left


func can_be_hacked() -> bool:
	return mode != Mode.DISABLED and mode != Mode.HACKED


# --- Ângulo -> quadro --------------------------------------------------------

## Ângulo de mira no espaço do sprite (antes de espelhar).
func _sprite_aim(world_aim: float) -> float:
	return 180.0 - world_aim if facing_left else world_aim


func _column_for(world_aim: float) -> int:
	var a := _sprite_aim(world_aim)
	var best := 0
	var best_d := INF
	for i in _aims.size():
		var d := absf(_aims[i] - a)
		if d < best_d:
			best_d = d
			best = i
	return best


## Ponto da lente (local) da coluna atual.
func lens_local() -> Vector2:
	var col := _column_for(aim_deg)
	var p := _lens[col] - _frame_size * 0.5
	if facing_left:
		p.x = -p.x
	return p


func _aim_limits() -> Vector2:
	# Limites do que o sprite consegue mostrar, no espaço do mundo.
	var lo := _aims.min() as float
	var hi := _aims.max() as float
	if facing_left:
		return Vector2(180.0 - hi, 180.0 - lo)
	return Vector2(lo, hi)


func _apply_frame() -> void:
	var key := "normal"
	match mode:
		Mode.ALERT:
			key = "alert"
		Mode.HACKED:
			key = "hacked"
		Mode.DISABLED:
			key = "disabled"
	sprite.texture = _textures[key]
	var period := 0.18 if mode == Mode.ALERT else 0.6
	var row := 0 if fmod(_blink, period * 2.0) < period else 1
	sprite.frame = row * _aims.size() + _column_for(aim_deg)


# --- Lógica ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_blink += delta
	_alarm_cooldown = maxf(_alarm_cooldown - delta, 0.0)
	match mode:
		Mode.SWEEP:
			_do_sweep(delta)
			if _sees_player():
				mode = Mode.ALERT
				_exposure = 0.0
				_lost_timer = 0.0
		Mode.ALERT:
			_do_alert(delta)
		Mode.HACKED:
			_mode_timer -= delta
			if _mode_timer <= 0.0:
				mode = Mode.DISABLED
				_mode_timer = disabled_time
		Mode.DISABLED:
			_mode_timer -= delta
			if _mode_timer <= 0.0:
				mode = Mode.SWEEP
	_apply_frame()
	_update_cone()
	queue_redraw()


func _do_sweep(delta: float) -> void:
	if _pause > 0.0:
		_pause -= delta
		return
	var lo := sweep_min_deg
	var hi := sweep_max_deg
	if facing_left:
		lo = 180.0 - sweep_max_deg
		hi = 180.0 - sweep_min_deg
	aim_deg += _sweep_dir * sweep_speed * delta
	if aim_deg >= hi:
		aim_deg = hi
		_sweep_dir = -1.0
		_pause = sweep_pause
	elif aim_deg <= lo:
		aim_deg = lo
		_sweep_dir = 1.0
		_pause = sweep_pause


func _do_alert(delta: float) -> void:
	var player := _player()
	var seen := _sees_player()
	if seen and player:
		_lost_timer = 0.0
		_exposure += delta
		var aim_point: Vector2 = player.call("get_aim_point")
		var to := aim_point - global_position - lens_local()
		var want := rad_to_deg(to.angle())
		var lim := _aim_limits()
		want = clampf(want, lim.x, lim.y)
		aim_deg = move_toward(aim_deg, want, track_speed * delta)
		if _exposure >= exposure_to_alarm and _alarm_cooldown <= 0.0:
			_alarm_cooldown = 4.0
			GameManager.raise_alarm(player.global_position)
	else:
		_lost_timer += delta
		_exposure = maxf(_exposure - delta, 0.0)
		if _lost_timer >= 1.5:
			mode = Mode.SWEEP


func _player() -> Node2D:
	return get_tree().get_first_node_in_group("Player") as Node2D


func _sees_player() -> bool:
	var player := _player()
	if player == null or not player.has_method("get_aim_point"):
		return false
	if player.has_method("is_detectable") and not player.is_detectable():
		return false
	var origin := global_position + lens_local()
	var target: Vector2 = player.get_aim_point()
	var to := target - origin
	if to.length() > vision_range:
		return false
	var diff := absf(wrapf(rad_to_deg(to.angle()) - aim_deg, -180.0, 180.0))
	if diff > fov_deg * 0.5:
		return false
	var q := PhysicsRayQueryParameters2D.create(origin, target, world_mask)
	q.exclude = [(player as CollisionObject2D).get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func _on_hacked() -> void:
	mode = Mode.HACKED
	_mode_timer = 0.6
	_exposure = 0.0


# --- Cone de visão -----------------------------------------------------------

func _update_cone() -> void:
	_cone.clear()
	if mode == Mode.DISABLED or mode == Mode.HACKED:
		return
	var origin := lens_local()
	var g_origin := global_position + origin
	_cone.append(origin)
	var steps := 10
	var space := get_world_2d().direct_space_state
	for i in steps + 1:
		var a := deg_to_rad(aim_deg - fov_deg * 0.5 + fov_deg * float(i) / float(steps))
		var end := g_origin + Vector2.from_angle(a) * vision_range
		var q := PhysicsRayQueryParameters2D.create(g_origin, end, world_mask)
		var player := _player()
		if player is CollisionObject2D:
			q.exclude = [(player as CollisionObject2D).get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			end = hit["position"]
		_cone.append(end - global_position)


func _draw() -> void:
	_draw_exposure_bar()
	if _cone.size() < 3:
		return
	var col := Color(1.0, 0.45, 0.15, 0.13) if mode == Mode.SWEEP else Color(1.0, 0.1, 0.12, 0.28)
	draw_colored_polygon(_cone, col)
	var edge := Color(col.r, col.g, col.b, 0.5)
	draw_line(_cone[0], _cone[1], edge, 1.0)
	draw_line(_cone[0], _cone[_cone.size() - 1], edge, 1.0)


func _draw_exposure_bar() -> void:
	if mode != Mode.ALERT or _exposure <= 0.0:
		return
	var ratio := clampf(_exposure / exposure_to_alarm, 0.0, 1.0)
	var w := 30.0
	var h := 4.0
	var pos := Vector2(-w * 0.5, _frame_size.y * 0.5 + 4.0)
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(0, 0, 0, 0.75))
	var col := Color(1.0, 0.8, 0.15).lerp(Color(1.0, 0.1, 0.25), ratio)
	if ratio >= 1.0 and fmod(_blink, 0.3) < 0.15:
		col = Color(1, 1, 1)
	draw_rect(Rect2(pos, Vector2(w * ratio, h)), col)
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(w + 2, h + 2)), Color(col.r, col.g, col.b, 0.9), false, 1.0)
