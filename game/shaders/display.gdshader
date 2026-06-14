shader_type canvas_item;

global uniform vec2 resolution;
uniform sampler2D noise;
uniform sampler2D world_view_texture;
uniform sampler2D overlay_view_texture;
uniform float display_white_out_amount;
uniform float display_red_outline_amount;
uniform float display_speed_lines_amount;

const float[16] bayer_matrix = float[16](
	0.0 / 16.0, 8.0 / 16.0, 2.0 / 16.0, 10.0 / 16.0,
	12.0 / 16.0, 4.0 / 16.0, 14.0 / 16.0, 6.0 / 16.0,
	3.0 / 16.0, 11.0 / 16.0, 1.0 / 16.0, 9.0 / 16.0,
	15.0 / 16.0, 7.0 / 16.0, 13.0 / 16.0, 5.0 / 16.0
);

const float luminance_steps = 14.;

float bayer4x4(ivec2 p) {
	int x = p.x & 3;
	int y = p.y & 3;
	int index = x + y * 4;

	return bayer_matrix[index];
}

float inv_lerp(float from, float to, float value){
	return (value - from) / (to - from);
}

vec2 polar_coordinates(vec2 uv, vec2 center, float zoom, float repeat)
{
	vec2 dir = uv - center;
	float radius = length(dir) * 2.0;
	float angle = atan(dir.y, dir.x) * 1.0/(PI * 2.0);
	return mod(vec2(radius * zoom, angle * repeat), 1.0);
}

vec2 rotate_uv(vec2 uv, vec2 pivot, float rotation) {
	float cosa = cos(rotation);
	float sina = sin(rotation);
	uv -= pivot;
	return vec2(
		cosa * uv.x - sina * uv.y,
		cosa * uv.y + sina * uv.x
	) + pivot;
}

void fragment() {
	// pixel and uv calculations
	vec2 pixel = floor(UV * resolution);
	vec2 uv = (pixel + 0.5) / resolution;

	// world color
	vec3 world_color = texture(world_view_texture, uv).rgb;

	world_color = mix(world_color, vec3(1.0), display_white_out_amount);

	vec2 polar_uv = polar_coordinates(rotate_uv(uv, vec2(0.5), floor(fract(TIME) * 5.0)) , vec2(0.5), 0.01, 3.0);
	vec3 lines = texture(noise, polar_uv).rgb;
	float mask_value = length(uv - vec2(0.5));
	float mask = inv_lerp(0.0, 0.3, mask_value);
	float result = 1.3 - (mask * 0.4);
	result = smoothstep(result, result + 1.0, lines.r);
	world_color = mix(world_color, vec3(1.0), result * display_speed_lines_amount);

	vec2 vignette_uv = uv * (1.0 - uv.yx);
	float vignette_strength = vignette_uv.x * vignette_uv.y * 30.0;
	vignette_strength = min(pow(vignette_strength, 0.25), 1.0);
	world_color = mix(mix(vec3(0.004, 0.004, 0.009) * 4., vec3(0.5, 0.0, 0.0), display_red_outline_amount), world_color, vignette_strength);

	float world_color_luminance = dot(world_color, vec3(0.2126, 0.7152, 0.0722));
	float stepped_world_color_luminance = (floor((world_color_luminance + (bayer4x4(ivec2(pixel)) - 0.5) / luminance_steps) * luminance_steps) + 0.5) / luminance_steps;
	world_color *= stepped_world_color_luminance / world_color_luminance;

	// overlay color
	vec4 overlay_color_alpha = texture(overlay_view_texture, uv);
	vec3 overlay_color = overlay_color_alpha.rgb;
	float overlay_alpha = overlay_color_alpha.a;

	// final color
	vec3 final_color = mix(world_color, overlay_color, overlay_alpha);

	// write out
	COLOR = vec4(final_color, 1.0);
}
