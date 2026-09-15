shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform int mode : hint_range(0, 4) = 0;

void fragment() {
	vec4 color = texture(screen_texture, SCREEN_UV);
	if (mode == 0) {
		COLOR = color;
	} else if (mode == 1) {
		// Protanopia (Deficiência de vermelho)
		float r = 0.56667 * color.r + 0.43333 * color.g;
		float g = 0.55833 * color.r + 0.44167 * color.g;
		float b = 0.24167 * color.g + 0.75833 * color.b;
		COLOR = vec4(r, g, b, color.a);
	} else if (mode == 2) {
		// Deuteranopia (Deficiência de verde)
		float r = 0.625 * color.r + 0.375 * color.g;
		float g = 0.700 * color.r + 0.300 * color.g;
		float b = 0.300 * color.g + 0.700 * color.b;
		COLOR = vec4(r, g, b, color.a);
	} else if (mode == 3) {
		// Tritanopia (Deficiência de azul)
		float r = 0.950 * color.r + 0.050 * color.g;
		float g = 0.43333 * color.g + 0.56667 * color.b;
		float b = 0.475 * color.g + 0.525 * color.b;
		COLOR = vec4(r, g, b, color.a);
	} else if (mode == 4) {
		// Acromatopsia (Monocromático / Escala de Cinza)
		float gray = dot(color.rgb, vec3(0.299, 0.587, 0.114));
		COLOR = vec4(vec3(gray), color.a);
	}
}
