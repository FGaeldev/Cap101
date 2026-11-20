shader_type canvas_item;
// Fog of war for the book map (page_map.gd). Covers the land of the map
// texture with drifting pixel clouds, except round clearings around the
// places the game actually has (one per marker). Drawn in the map texture's
// own pixel grid so it stays as blocky as the map itself.

uniform sampler2D map_tex : filter_nearest;   // aklan_map.png, used as the land mask
uniform vec2 map_px = vec2(208.0, 147.0);    // map texture size in texels
uniform vec2 host_size = vec2(615.0, 288.0); // this rect's size in UI px
uniform int clear_count = 0;
uniform vec2 clear_pos[16];                  // clearing centres, UI px in this rect
uniform float clear_radius = 26.0;           // UI px
uniform float edge = 10.0;                   // dithered fade width, UI px
uniform vec4 fog_light : source_color = vec4(0.62, 0.5, 0.39, 1.0);
uniform vec4 fog_dark : source_color = vec4(0.53, 0.42, 0.32, 1.0);
uniform float fog_alpha = 0.8;
uniform float drift_speed = 0.6;             // texels per second

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0,
			3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

void fragment() {
	// Snap to the map's texel grid.
	vec2 texel = floor(UV * map_px);
	vec2 suv = (texel + 0.5) / map_px;

	float land = texture(map_tex, suv).a;
	// Coastline texels (land next to empty) stay unfogged so the province's
	// shape still reads through the fog.
	vec2 tx = 1.0 / map_px;
	float coast = min(min(texture(map_tex, suv + vec2(tx.x, 0.0)).a, texture(map_tex, suv - vec2(tx.x, 0.0)).a),
			min(texture(map_tex, suv + vec2(0.0, tx.y)).a, texture(map_tex, suv - vec2(0.0, tx.y)).a));
	if (land < 0.1 || coast < 0.1) {
		COLOR = vec4(0.0);
	} else {
		// How far inside a clearing (0 = full fog, 1 = clear).
		vec2 p = suv * host_size;
		// Left unclamped until after the edge noise, so the noise only roughens
		// the rim and never speckles the middle of a clearing.
		float clear = -1.0;
		for (int i = 0; i < clear_count; i++) {
			float d = distance(p, clear_pos[i]);
			clear = max(clear, (clear_radius + edge - d) / edge);
		}
		// Ragged edge: wobble the clearing with noise so it isn't a perfect circle.
		clear = clamp(clear + (vnoise(texel * 0.35) - 0.5) * 0.5, 0.0, 1.0);
		float fog = (1.0 - clear) > bayer4(texel) ? 1.0 : 0.0;

		// Drifting clouds: two octaves, two tones, dithered.
		vec2 q = texel + vec2(TIME * drift_speed, TIME * drift_speed * 0.3);
		float n = vnoise(q * 0.12) * 0.65 + vnoise(q * 0.3) * 0.35;
		vec3 col = (n > 0.42 + bayer4(texel + 2.0) * 0.16) ? fog_light.rgb : fog_dark.rgb;
		COLOR = vec4(col, fog * fog_alpha);
	}
}
