shader_type canvas_item;

uniform float fade_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);

    // Quantize into 4 discrete NES stages so the stepped palette-collapse look is preserved
    // while still accepting a smooth float for tweening
    float stage = floor(fade_amount * 4.0);

    if (stage >= 4.0) {
        COLOR = vec4(0.0, 0.0, 0.0, screen_color.a);
    } else if (stage <= 0.0) {
        COLOR = screen_color;
    } else {
        float reduction = stage / 3.0;
        vec3 collapsed = max(vec3(0.0), screen_color.rgb - vec3(reduction));
        COLOR = vec4(collapsed, screen_color.a);
    }
}
