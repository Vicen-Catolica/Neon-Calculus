shader_type canvas_item;

// Captura a imagem renderizada atrás do ColorRect no Godot 4
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Parâmetros editáveis no Inspetor
uniform float scanline_count : hint_range(100.0, 1000.0, 10.0) = 400.0;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float noise_amount : hint_range(0.0, 0.3) = 0.04;
uniform float vignette_intensity : hint_range(0.0, 2.0) = 0.6;
uniform float static_flicker : hint_range(0.0, 1.0) = 0.03;

// Gerador de ruído pseudo-aleatório
float random(vec2 uv) {
    return fract(sin(dot(uv.xy, vec2(12.9898, 78.233))) * 43758.5453123);
}

void fragment() {
    vec2 uv = SCREEN_UV;
    
    // 1. Amostra a cor original da tela
    vec4 color = texture(SCREEN_TEXTURE, uv);
    
    // 2. Scanlines horizontais
    float scanline = sin(uv.y * scanline_count * 3.14159 * 2.0);
    scanline = (scanline + 1.0) * 0.5;
    color.rgb -= scanline * scanline_intensity * color.rgb;
    
    // 3. Ruído estático (Grit/Grain Cyberpunk)
    float noise = random(uv + vec2(TIME * 0.1, TIME * 0.2));
    color.rgb += (noise - 0.5) * noise_amount;
    
    // 4. Oscilação de brilho (Flicker de TV CRT antiga)
    float flicker = sin(TIME * 15.0) * static_flicker;
    color.rgb += flicker;
    
    // 5. Vinheta (Escurecimento nos cantos da tela)
    float dist = distance(uv, vec2(0.5));
    color.rgb *= smoothstep(0.8, 0.2, dist * vignette_intensity);
    
    COLOR = color;
}