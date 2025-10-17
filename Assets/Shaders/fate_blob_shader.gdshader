shader_type canvas_item;
render_mode blend_mix;

//
// === CONFIGURABLE UNIFORMS ===
//
uniform vec3 color1 : source_color = vec3(1.0, 0.37, 1.0);
uniform vec3 color2 : source_color = vec3(0.1, 0.55, 1.0);
uniform float time_scale = 0.5;  // Animation speed
uniform float scale = 1.9;       // Overall zoom level
uniform float pixel_size : hint_range(1.0, 64.0) = 4.0; // Pixelation resolution

//
// === UTILITY FUNCTIONS ===
//
vec4 perm(vec4 x) {
	x = ((x * 34.0) + 1.0) * x;
	return x - floor(x * (1.0 / 289.0)) * 289.0;
}

float noise(vec3 p) {
	vec3 a = floor(p);
	vec3 d = p - a;
	d = d * d * (3.0 - 2.0 * d);

	vec4 b = a.xxyy + vec4(0.0, 1.0, 0.0, 1.0);
	vec4 k1 = perm(b.xyxy);
	vec4 k2 = perm(k1.xyxy + b.zzww);

	vec4 c = k2 + a.zzzz;
	vec4 k3 = perm(c);
	vec4 k4 = perm(c + 1.0);

	vec4 o1 = fract(k3 * 0.02439024);
	vec4 o2 = fract(k4 * 0.02439024);

	vec4 o3 = o2 * d.z + o1 * (1.0 - d.z);
	vec2 o4 = o3.yw * d.x + o3.xz * (1.0 - d.x);

	return o4.y * d.y + o4.x * (1.0 - d.y);
}

float specular(vec3 light_dir, vec3 ray_dir, vec3 normal) {
	return max(0.0, dot(normal, normalize(light_dir + ray_dir)));
}

//
// === CORE COLOR CALCULATION ===
//
vec4 get_color(vec2 uv, vec3 col, float seed, float min_res, float t) {
	// Make the movement symmetrical by basing both noise calls on absolute UV
	vec2 suv = vec2(abs(uv.x), abs(uv.y));
	vec3 p = vec3(suv, t * time_scale + seed);

	// Balanced wobble on both axes
	uv += noise(p * 0.7) * 0.35 - noise(-p * 1.2) * 0.2;
	float l = length(uv);
	vec3 n = normalize(vec3(uv, -1.0));
	const vec3 light_dir = vec3(0.6666, 0.6666, -0.3333);
	vec3 view_dir = -normalize(vec3(uv, 1.0));

	float light = 0.35 * pow(specular(light_dir, view_dir, n), 16.0);
	float m = smoothstep(1.0, 1.0 - 3.0 / min_res, l);

	vec3 color = pow(max(0.0, 2.0 - sqrt(l)), 10.0) * col;
	vec3 nc = abs(n + vec3(0.0, 0.0, 0.3));
	col = normalize(col + pow(nc, vec3(7.0)) * vec3(7.0)) + col * 0.35;

	color = mix(color, col, m) + light;
	return vec4(color, m);
}

//
// === MAIN FRAGMENT ===
//
void fragment() {
	vec2 frag_coord = FRAGCOORD.xy;
	vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
	float min_res = min(resolution.x, resolution.y);

	// --- Pixelation ---
	if (pixel_size > 1.0) {
		frag_coord = floor(frag_coord / pixel_size) * pixel_size;
	}

	// --- Normalized symmetric coordinates ---
	vec2 uv = (frag_coord * 2.0 - resolution) / min_res * scale;

	float t = TIME;

	vec4 col1 = get_color(uv * 0.98, color1, 0.0, min_res, t);
	vec4 col2 = get_color(uv, color2, -612.734, min_res, t);

	vec3 col = mix(col1.rgb, col2.rgb, clamp(0.5 + 0.5 * (col2.w - col1.w), 0.0, 1.0));

	COLOR = vec4(col, 1.0);
}
