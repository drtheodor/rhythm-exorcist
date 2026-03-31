shader_type canvas_item;

uniform sampler2D glitch_tiles : filter_nearest;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float glitch_intensity : hint_range(0.0, 1.0) = 0.0;
uniform float tile_coverage : hint_range(0.0, 1.0) = 0.0;
uniform int min_tile_index : hint_range(0, 2048) = 0;
uniform int max_tile_index : hint_range(0, 2048) = 64;

const int TILES_HORIZONTAL = 32;
const int TILES_VERTICAL = 28;

const int ATLAS_TILES_PER_ROW = 45;
const float ATLAS_TILE_UV = 8.0 / 360.0;

float noise(vec2 uv, float seed) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233)) + seed) * 43758.5453);
}

vec4 sample_glitch_tile(vec2 screen_uv, int tile_index) {
	int tile_x = tile_index % ATLAS_TILES_PER_ROW;
	int tile_y = tile_index / ATLAS_TILES_PER_ROW;

	vec2 tile_uv = fract(screen_uv * vec2(float(TILES_HORIZONTAL), float(TILES_VERTICAL)));

	vec2 atlas_uv = vec2(
		float(tile_x) * ATLAS_TILE_UV + tile_uv.x * ATLAS_TILE_UV,
		float(tile_y) * ATLAS_TILE_UV + tile_uv.y * ATLAS_TILE_UV
	);

	return texture(glitch_tiles, atlas_uv);
}

void fragment() {
	vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);

	vec2 grid_pos = vec2(
		float(int(SCREEN_UV.x * float(TILES_HORIZONTAL))),
		float(int(SCREEN_UV.y * float(TILES_VERTICAL)))
	);

	float tile_rand = noise(grid_pos, floor(TIME * 10.0));
	float should_glitch = step(tile_rand, tile_coverage);

	float rand_tile = noise(grid_pos + vec2(0.5, 0.5), floor(TIME * 10.0));
	float tile_range = float(max_tile_index - min_tile_index);
	int tile_idx = min_tile_index + int(rand_tile * tile_range);

	vec4 glitch_sample = sample_glitch_tile(SCREEN_UV, tile_idx);

	float screen_blend = glitch_intensity * 0.5;
	vec4 result = mix(glitch_sample, screen_color, screen_blend);

	COLOR = mix(screen_color, result, should_glitch);
}
