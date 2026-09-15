shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 uv = UV;
	
	// Deslocamento horizontal aleatório por faixas
	if (glitch_intensity > 0.0) {
		float line_noise = sin(uv.y * 50.0 + TIME * 30.0);
		if (line_noise > 0.5) {
			uv.x += (fract(sin(TIME) * 43758.5453) - 0.5) * 0.05 * glitch_intensity;
		}
	}
	
	// Separação dos canais RGB (Aberração Cromática)
	float shift = 0.02 * glitch_intensity;
	float r = texture(TEXTURE, vec2(uv.x + shift, uv.y)).r;
	float g = texture(TEXTURE, uv).g;
	float b = texture(TEXTURE, vec2(uv.x - shift, uv.y)).b;
	float a = texture(TEXTURE, uv).a;
	
	COLOR = vec4(r, g, b, a);
}