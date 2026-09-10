shader_type canvas_item;

uniform float velocidade : hint_range(0.1, 10.0) = 3.0;
uniform float intensidade : hint_range(0.0, 1.0) = 0.4;

float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV;
	
	// Gera pulsos de tempo aleatórios
	float tempo_snap = floor(TIME * velocidade * 8.0);
	float ruído = random(vec2(tempo_snap, 1.0));
	
	// Dispara o deslocamento horizontal de linhas em rajadas
	if (ruído > 0.65) {
		float linha_ruído = random(vec2(floor(uv.y * 25.0), tempo_snap));
		if (linha_ruído > 0.4) {
			uv.x += (random(vec2(tempo_snap, 2.0)) - 0.5) * 0.06 * intensidade;
		}
	}
	
	// Separação de canais RGB (Aberração Cromática)
	float shift = 0.005;
	if (ruído > 0.65) {
		shift += 0.02 * intensidade;
	}
	
	float r = texture(TEXTURE, vec2(uv.x + shift, uv.y)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, vec2(uv.x - shift, uv.y)).b;
	float a = texture(TEXTURE, uv).a;
	
	COLOR = vec4(r, g, b, a);
}