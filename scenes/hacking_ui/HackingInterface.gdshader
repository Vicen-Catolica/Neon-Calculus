shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_count : hint_range(0.0, 1080.0) = 300.0;

void fragment() {
    vec2 uv = SCREEN_UV;
    vec4 screen_color = texture(SCREEN_TEXTURE, uv);
    
    // Efeito de Scanlines (linhas horizontais de TV antiga)
    float scanline = sin(uv.y * scanline_count * 3.14159) * 0.04;
    screen_color.rgb -= scanline;
    
    // Vinheta suave nas bordas
    float vignette = uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y);
    vignette = clamp(pow(16.0 * vignette, 0.25), 0.0, 1.0);
    screen_color.rgb *= vignette;
    
    COLOR = screen_color;
}