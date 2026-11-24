shader_type canvas_item;
// Filtro de daltonismo (Opções > Acessibilidade). Modos 1–3 fazem DALTONIZAÇÃO
// (correção), não simulação: calcula como a pessoa com a deficiência veria a cor,
// pega a diferença que ela perde e a joga nos canais que ela enxerga. Assim
// vermelho (lasers, alertas) e verde (alvos, acertos) continuam distinguíveis.
// (Antes o filtro só simulava a deficiência, o que piorava a leitura.)
// Modo 4 (acromatopsia): escala de cinza, para quem não distingue cores.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform int mode : hint_range(0, 4) = 0;

const mat3 RGB_TO_LMS = mat3(
	vec3(17.8824, 3.45565, 0.0299566),
	vec3(43.5161, 27.1554, 0.184309),
	vec3(4.11935, 3.86714, 1.46709));
const mat3 LMS_TO_RGB = mat3(
	vec3(0.0809444479, -0.0102485335, -0.000365296938),
	vec3(-0.130504409, 0.0540193266, -0.00412161469),
	vec3(0.116721066, -0.113614708, 0.693511405));

vec3 simulate(vec3 rgb, int m) {
	vec3 lms = RGB_TO_LMS * rgb;
	if (m == 1) {        // protanopia: sem cones L
		lms.x = 2.02344 * lms.y - 2.52581 * lms.z;
	} else if (m == 2) { // deuteranopia: sem cones M
		lms.y = 0.494207 * lms.x + 1.24827 * lms.z;
	} else {             // tritanopia: sem cones S
		lms.z = -0.395913 * lms.x + 0.801109 * lms.y;
	}
	// fora do gamut (ex.: ciano no modo tritan) estourava o erro e apagava o canal
	return clamp(LMS_TO_RGB * lms, 0.0, 1.0);
}

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	if (mode >= 1 && mode <= 3) {
		vec3 err = color.rgb - simulate(color.rgb, mode);
		// Pesos ajustados para a paleta do jogo (vermelho, verde, laranja,
		// amarelo, ciano, rosa): maximizam a menor diferença entre essas cores
		// vistas pela pessoa daltônica (ver docs/GUIA_REVISAO.md).
		vec3 shift;
		if (mode == 1) {        // protan: perda no vermelho vai para o azul
			shift = vec3(0.0, err.g, err.b + 0.7 * err.r);
		} else if (mode == 2) { // deutan: idem, mais forte
			shift = 1.5 * vec3(0.0, err.g, err.b + 0.5 * err.r);
		} else {                // tritan: perda no azul vai para o verde
			shift = vec3(err.r, err.g + err.b, 0.0);
		}
		COLOR = vec4(clamp(color.rgb + shift, 0.0, 1.0), color.a);
	} else if (mode == 4) {
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(vec3(gray), color.a);
	} else {
		COLOR = color;
	}
}
