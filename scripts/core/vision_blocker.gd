class_name VisionBlocker
## Obstáculos de visão sem colisão (vapor, fumaça): guardas e câmeras não
## enxergam através deles, mas o jogador passa normalmente.
##
## Qualquer nó no grupo "vision_blocker" que tenha `get_block_rect() -> Rect2`
## (retângulo global) e `is_blocking() -> bool` participa. O teste é segmento ×
## retângulo, sem física extra.

const GROUP := "vision_blocker"


## true se a linha de visão de `from` até `to` atravessa algum bloqueio ativo.
static func line_blocked(tree: SceneTree, from: Vector2, to: Vector2) -> bool:
	if tree == null:
		return false
	for n in tree.get_nodes_in_group(GROUP):
		if n.has_method("is_blocking") and not n.is_blocking():
			continue
		if segment_hits_rect(from, to, n.get_block_rect()):
			return true
	return false


## Corta o segmento no primeiro bloqueio ativo: devolve o ponto onde a visão
## para (ou `to`, se nada bloqueia). Usado para desenhar os cones de visão.
static func clip(tree: SceneTree, from: Vector2, to: Vector2) -> Vector2:
	if tree == null:
		return to
	var best := to
	var best_d := from.distance_squared_to(to)
	for n in tree.get_nodes_in_group(GROUP):
		if n.has_method("is_blocking") and not n.is_blocking():
			continue
		var r: Rect2 = n.get_block_rect()
		if r.has_point(from):
			return from
		var p0 := r.position
		var p1 := r.position + Vector2(r.size.x, 0)
		var p2 := r.end
		var p3 := r.position + Vector2(0, r.size.y)
		for edge in [[p0, p1], [p1, p2], [p2, p3], [p3, p0]]:
			var hit: Variant = Geometry2D.segment_intersects_segment(from, to, edge[0], edge[1])
			if hit != null and from.distance_squared_to(hit) < best_d:
				best = hit
				best_d = from.distance_squared_to(hit)
	return best


## Segmento AB cruza (ou tem um ponto dentro de) o retângulo R?
static func segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var p0 := r.position
	var p1 := r.position + Vector2(r.size.x, 0)
	var p2 := r.end
	var p3 := r.position + Vector2(0, r.size.y)
	for edge in [[p0, p1], [p1, p2], [p2, p3], [p3, p0]]:
		if Geometry2D.segment_intersects_segment(a, b, edge[0], edge[1]) != null:
			return true
	return false
