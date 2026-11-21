class_name DuelHit
extends RefCounted
## Dano dos ataques do Duelo de Paradoxo: tira Defesa Neural do Eduardo com
## invulnerabilidade curta depois de cada golpe (dois ataques ao mesmo tempo não
## somam). O corpo é o colisor ativo do Eduardo (agachado é mais baixo).

const IFRAMES_MS := 1000


## Retângulo global do corpo (em pé ou agachado).
static func body_rect(player: Node2D) -> Rect2:
	for c in player.get_children():
		if c is CollisionShape2D and not c.disabled and c.shape:
			var r: Rect2 = c.shape.get_rect()
			return Rect2(c.global_position + r.position, r.size)
	return Rect2(player.global_position - Vector2(14, 110), Vector2(28, 110))


## Aplica o dano se o Eduardo não estiver invulnerável. Devolve true se acertou.
static func hit(player: Node2D, amount: float) -> bool:
	if player == null or player.get("is_dead"):
		return false
	var now := Time.get_ticks_msec()
	if int(player.get_meta("duel_iframe_until", 0)) > now:
		return false
	player.set_meta("duel_iframe_until", now + IFRAMES_MS)
	player.get_tree().call_group("stealth_hud", "_flash", "ATAQUE DO NÚCLEO — DEFESA NEURAL -%d" % int(amount), Color(1.0, 0.2, 0.25))
	if player.has_method("take_damage"):
		player.take_damage(amount)
	return true
