shader_type canvas_item;

uniform vec4 white_replace : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 gray_replace : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform vec4 black_replace : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
    vec4 tex_color = texture(TEXTURE, UV);
    float luma = dot(tex_color.rgb, vec3(0.299, 0.587, 0.114));

    vec3 final_rgb;

    if (luma > 0.66) {
        final_rgb = white_replace.rgb;
    } else if (luma > 0.33) {
        final_rgb = gray_replace.rgb;
    } else {
        final_rgb = black_replace.rgb;
    }

    COLOR = vec4(final_rgb, tex_color.a);
}