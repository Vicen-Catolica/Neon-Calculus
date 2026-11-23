class_name StateMaxAlert
extends EnemyState

@export var lose_interest_time: float = 3.0
var lose_sight_timer: float = 0.0
## Viu o Eduardo entrar no esconderijo: vai lá e o arranca de dentro.
var _pulling: bool = false
var _was_detected: bool = false
## Até onde ele "viu" o Eduardo se esconder.
const PULL_RANGE := 520.0

func enter() -> void:
	lose_sight_timer = 0.0
	_pulling = false
	_was_detected = false
	enemy.alarm_triggered.emit(enemy.last_known_player_pos)
	# Viu o Eduardo com os próprios olhos: chama os vizinhos pelo rádio.
	enemy.on_max_alert(enemy.entered_by_alarm())

func physics_update(delta: float) -> void:
	var target_player = enemy.get_player()
	if not target_player:
		state_machine.transition_to("Search")
		return

	# Checa se o player está visível OU dentro da área de audição
	# (escondido não faz barulho: a audição não conta)
	var hidden: bool = target_player.has_method("is_hidden") and target_player.is_hidden()
	var is_detected = enemy.is_player_in_los() or (enemy.is_player_in_hearing_area and not hidden)

	var dist_to_player = enemy.global_position.distance_to(target_player.global_position)

	# Escondeu-se na frente dele: não adianta, ele viu.
	if _was_detected and not is_detected and hidden and dist_to_player <= PULL_RANGE:
		_pulling = true
	if not hidden:
		_pulling = false
	_was_detected = is_detected
	if _pulling:
		lose_sight_timer = 0.0
		var t: Vector2 = target_player.global_position
		if absf(t.x - enemy.global_position.x) <= 36.0 and absf(t.y - enemy.global_position.y) <= 40.0:
			enemy.velocity.x = 0.0
			if target_player.has_method("pulled_from_hiding"):
				target_player.pulled_from_hiding(enemy.global_position)
			_pulling = false
		else:
			enemy.chase_move(t, enemy.chase_speed)
		enemy.move_and_slide()
		return

	if is_detected:
		lose_sight_timer = 0.0
		enemy.last_known_player_pos = target_player.global_position

		var dist_x = target_player.global_position.x - enemy.global_position.x
		if abs(dist_x) > 5.0:
			enemy.update_facing(sign(dist_x))

		# Só dispara o taser se tiver linha de visão real
		if dist_to_player <= enemy.attack_range and enemy.is_player_in_los() and not enemy.is_climbing():
			# Colado no Eduardo: recua enquanto atira (mantém distância de tiro).
			enemy.velocity.x = move_toward(enemy.velocity.x, enemy.back_off_velocity(target_player.global_position), enemy.chase_speed)
			enemy.try_fire_taser()
		else:
			# Persegue mudando de andar (pulo, escadas) em vez de só andar em x.
			enemy.chase_move(target_player.global_position, enemy.chase_speed)
	else:
		lose_sight_timer += delta
		
		# Move até a última posição conhecida do player
		enemy.chase_move(enemy.last_known_player_pos, enemy.chase_speed)

		# Passados os 3 segundos sem visão nem audição, vai para o estado de busca
		if lose_sight_timer >= lose_interest_time:
			state_machine.transition_to("Search")

	enemy.move_and_slide()
