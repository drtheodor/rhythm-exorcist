shader_type canvas_item;

// Set this slider from 0.0 to 1.0. 
// Use 10 steps (0.1, 0.2, etc.) for your specific requirement.
uniform float bright_amount : hint_range(0.0, 1.0) = 0.0;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
    
    // 1. Guard for Stage 0 (Perfect 1:1)
    if (bright_amount <= 0.001) {
        COLOR = screen_color;
    } 
    else if (bright_amount >= 0.999) {
        COLOR = vec4(1.0, 1.0, 1.0, screen_color.a);
    } 
    else {
        // 2. Get standard brightness
        float luma = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
        
        // 3. The "Shift" Logic
        // We calculate which colors are "hit" by the brightening wave.
        // As bright_amount increases, even the darkest pixels get pushed toward 1.0.
        float transition = max(0.0, luma + bright_amount);
        
        // 4. Quantization (The "NES" Step Effect)
        // Since you want 10 stages, we snap the result to 10 discrete levels.
        float quantized = floor(transition * 10.0) / 10.0;
        
        // 5. Apply the brightening
        // We find the difference between our new brightness and the original
        float diff = clamp(quantized - luma, 0.0, 1.0);
        
        // Add the difference to the original channels. 
        // This brightens the color while keeping it "snapped" to 10 levels.
        vec3 final_rgb = screen_color.rgb + vec3(diff);
        
        COLOR = vec4(clamp(final_rgb, 0.0, 1.0), screen_color.a);
    }
}