// water_gradient.gdshader -- tints a water TileMapLayer by height in the level:
// near_tint at near_y (the mangroves by the shore) blending to far_tint at far_y
// (the open sea). Smooth, so one layer of the same water tile shades gradually.
// Used by the Sea layer in bakhawan_trail.tscn. Positions are level pixels.
shader_type canvas_item;

uniform vec4 near_tint : source_color = vec4(0.62, 0.92, 0.66, 1.0);
uniform vec4 far_tint : source_color = vec4(0.74, 0.84, 1.0, 1.0);
uniform float near_y = 880.0;
uniform float far_y = 0.0;

varying float level_y;

void vertex() {
	level_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	float t = clamp((level_y - near_y) / (far_y - near_y), 0.0, 1.0);
	// COLOR already holds the texture colour here.
	COLOR *= mix(near_tint, far_tint, smoothstep(0.0, 1.0, t));
}
