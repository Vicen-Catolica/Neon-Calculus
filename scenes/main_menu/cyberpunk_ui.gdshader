shader_type canvas_item;

uniform float scanline_count : hint_range(10.0, 300.0) = 150.0;
uniform float scanline_intensity : hint_range(0.0, 0.5) = 0.12;
uniform float pulse_speed : hint_range(0.1, 5.0) = 2.0;

void fragment() {
    vec4 col = texture(TEXTURE, UV);
    
    // Efeito de linhas de varredura (Scanlines)
    float scanline = sin(UV.y * scanline_count * 3.14159) * 0.5 + 0.5;
    col.rgb -= scanline * scanline_intensity * col.a;
    
    // Pulso de brilho suave
    float pulse = sin(TIME * pulse_speed) * 0.08 + 0.92;
    col.rgb *= pulse;
    
    COLOR = col;
}