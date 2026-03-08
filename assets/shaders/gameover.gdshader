shader_type canvas_item;

uniform float dark_amount : hint_range(0.0, 1.0) = 0.0;
uniform float white_threshold : hint_range(0.0, 1.0) = 0.95;
uniform float flash_speed : hint_range(0.0, 30.0) = 10.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    if (dark_amount <= 0.001) {
        COLOR = screen_color;
    } 
    else if (dark_amount >= 0.999) {
        COLOR = vec4(0.0, 0.0, 0.0, screen_color.a);
    } 
    else {
        vec3 processed_color = screen_color.rgb;

        if (screen_color.r > white_threshold && 
            screen_color.g > white_threshold && 
            screen_color.b > white_threshold) {
            
            float flash = step(0.5, sin(TIME * flash_speed));
            processed_color = mix(screen_color.rgb, vec3(1.0, 0.0, 0.0), flash);
        }

        float snapped_darkness = floor(dark_amount * 10.0) / 10.0;
        vec3 final_rgb = max(vec3(0.0), processed_color - vec3(snapped_darkness));
        final_rgb = floor(final_rgb * 10.0 + 0.5) / 10.0;
        
        COLOR = vec4(final_rgb, screen_color.a);
    }
}