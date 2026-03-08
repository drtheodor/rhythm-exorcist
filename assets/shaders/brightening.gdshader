shader_type canvas_item;

// Set this slider from 0.0 to 1.0. 
// Use 10 steps (0.1, 0.2, etc.) for your specific requirement.
uniform float bright_amount : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    if (bright_amount <= 0.001) {
        COLOR = screen_color;
    } 
    else if (bright_amount >= 0.999) {
        COLOR = vec4(1.0, 1.0, 1.0, screen_color.a);
    } 
    else {
        float luma = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
        

        float transition = max(0.0, luma + bright_amount);
        

        float quantized = floor(transition * 10.0) / 10.0;
        

        float diff = clamp(quantized - luma, 0.0, 1.0);
        

        vec3 final_rgb = screen_color.rgb + vec3(diff);
        
        COLOR = vec4(clamp(final_rgb, 0.0, 1.0), screen_color.a);
    }
}