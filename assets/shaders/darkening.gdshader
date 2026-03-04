shader_type canvas_item;

uniform int fade_stage : hint_range(0, 4) = 0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    if (fade_stage <= 0) {
        COLOR = screen_color;
    } 
    else if (fade_stage >= 4) {
        COLOR = vec4(0.0, 0.0, 0.0, screen_color.a);
    } 
    else {

        float luma = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
        
        float step_size = 1.0 / 3.0; 
        
        float reduction = float(fade_stage) * step_size;
        
        vec3 collapsed_color = max(vec3(0.0), screen_color.rgb - vec3(reduction));
        
        COLOR = vec4(collapsed_color, screen_color.a);
    }
}