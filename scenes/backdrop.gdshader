shader_type canvas_item;
// Competition-hall blue behind the cube: a soft spotlight, faint floor grid.

void fragment() {
	vec2 uv = UV;
	float d = distance(uv, vec2(0.5, 0.32));
	vec3 col = mix(vec3(0.13, 0.17, 0.33), vec3(0.03, 0.04, 0.09), smoothstep(0.0, 0.8, d));
	vec2 g = abs(fract(FRAGCOORD.xy / 48.0) - 0.5);
	col += vec3(0.02, 0.03, 0.06) * step(0.47, max(g.x, g.y));
	col *= 1.0 - 0.4 * smoothstep(0.4, 1.0, distance(uv, vec2(0.5)));
	COLOR = vec4(col, 1.0);
}
