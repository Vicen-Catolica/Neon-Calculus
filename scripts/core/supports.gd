extends RefCounted
## (Carregado com preload por quem usa: `const Supports := preload(...)`.)
## Apoios visuais para objetos que ficariam "flutuando": câmera de parede sem
## parede atrás, emissor de laser sem teto em cima, porta mais baixa que o teto.
## Depois do primeiro quadro de física, o objeto procura o teto (ou o chão)
## com um raio e desenha uma haste/verga até lá. Só visual: não colide.

const WORLD_MASK := 1
const STEEL := Color(0.2, 0.22, 0.26)
const STEEL_HI := Color(0.42, 0.45, 0.5)
const HAZARD := Color(0.95, 0.72, 0.1)


## Ponto atingido por um raio no mundo (ou null). Ignora áreas.
static func hit(node: Node2D, from: Vector2, to: Vector2, exclude: Array[RID] = []) -> Variant:
	var q := PhysicsRayQueryParameters2D.create(from, to, WORLD_MASK)
	q.exclude = exclude
	q.collide_with_areas = false
	var r := node.get_world_2d().direct_space_state.intersect_ray(q)
	return r["position"] if not r.is_empty() else null


## Haste vertical de `a` até `b` (globais), presa em `parent` sem herdar a
## rotação/escala dele.
static func pole(parent: Node, a: Vector2, b: Vector2, width: float = 4.0, node_name: String = "Support") -> Node2D:
	var root := Node2D.new()
	root.name = node_name
	root.top_level = true
	var body := Line2D.new()
	body.width = width
	body.default_color = STEEL
	body.points = PackedVector2Array([a, b])
	root.add_child(body)
	var hi := Line2D.new()
	hi.width = 1.0
	hi.default_color = STEEL_HI
	hi.points = PackedVector2Array([a + Vector2(-width * 0.25, 0), b + Vector2(-width * 0.25, 0)])
	root.add_child(hi)
	# chapinha de fixação na ponta presa ao teto/chão
	var plate := Polygon2D.new()
	plate.color = STEEL_HI
	var s := signf(b.y - a.y) if b.y != a.y else 1.0
	plate.polygon = PackedVector2Array([b + Vector2(-8, 0), b + Vector2(8, 0), b + Vector2(8, -3 * s), b + Vector2(-8, -3 * s)])
	root.add_child(plate)
	parent.add_child(root)
	return root


## Verga de aço sobre uma porta: de `top` (alto da porta) até `ceiling`.
static func header(parent: Node, x: float, top: float, ceiling: float, half_w: float = 34.0) -> Node2D:
	var root := Node2D.new()
	root.name = "DoorHeader"
	root.top_level = true
	var body := Polygon2D.new()
	body.color = Color(0.16, 0.18, 0.21)
	body.polygon = PackedVector2Array([Vector2(x - half_w, ceiling), Vector2(x + half_w, ceiling), Vector2(x + half_w, top + 4), Vector2(x - half_w, top + 4)])
	root.add_child(body)
	for sx in [-1.0, 1.0]:
		var rail := Polygon2D.new()
		rail.color = Color(0.32, 0.35, 0.4)
		var x0: float = x + sx * half_w
		var x1: float = x + sx * (half_w - 6.0)
		rail.polygon = PackedVector2Array([Vector2(x0, ceiling), Vector2(x1, ceiling), Vector2(x1, top + 4), Vector2(x0, top + 4)])
		root.add_child(rail)
	var stripe_h := minf(10.0, (top + 4.0) - ceiling)
	var n := 6
	for i in n:
		var st := Polygon2D.new()
		st.color = HAZARD if i % 2 == 0 else Color(0.08, 0.08, 0.08)
		var xa := x - half_w + 2.0 * half_w * i / n
		var xb := x - half_w + 2.0 * half_w * (i + 1) / n
		var yb := top + 4.0
		var ya := yb - stripe_h
		st.polygon = PackedVector2Array([Vector2(xa + 4, ya), Vector2(xb + 4, ya), Vector2(xb, yb), Vector2(xa, yb)])
		root.add_child(st)
	parent.add_child(root)
	return root
