shader_type canvas_item;

uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;

void vertex() {
	if (glitch_intensity > 0.0) {
		// Desloca os vértices horizontalmente em faixas aleatórias
		float noise = fract(sin(dot(VERTEX, vec2(12.9898, 78.233)) + TIME * 20.0) * 43758.5453);
		if (noise > 0.3) {
			VERTEX.x += (fract(sin(TIME * 15.0) * 43758.5453) - 0.5) * 12.0 * glitch_intensity;
		}
	}
}

void fragment() {
	if (glitch_intensity > 0.0) {
		// Pisca o tom ciano/neon levemente
		float noise = fract(sin(TIME * 30.0) * 43758.5453);
		if (noise > 0.6) {
			COLOR.rgb += vec3(0.0, 0.3, 0.4) * glitch_intensity;
		}
	}
}