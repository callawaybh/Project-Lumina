shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(0.5, 0.05, 1.0, 1.0);
uniform float strength = 0.1;
void fragment() {
    float soft_edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
    float axial_fade = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.25, 1.0, UV.y));
    ALBEDO = tint.rgb;
    EMISSION = tint.rgb * 1.5;
    ALPHA = soft_edge * axial_fade * strength;
}
