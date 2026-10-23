shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

// This is painted into the terrain surface itself. No floating ring mesh,
// raycasts around a circumference, depth-test hacks or decals required.
uniform vec4 stone_color : source_color = vec4(0.55, 0.44, 0.32, 1.0);
uniform bool target_active = false;
uniform vec3 dig_center_world = vec3(0.0, 0.0, 0.0);
uniform float dig_radius = 1.45;
uniform float edge_width = 0.13;
uniform vec4 ring_color : source_color = vec4(1.0, 0.83, 0.11, 1.0);

varying vec3 world_point;

void vertex() {
    world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    ALBEDO = stone_color.rgb;
    ROUGHNESS = 0.97;
    SPECULAR = 0.0;
    if (target_active) {
        // Intersection of the spherical excavation boundary and actual surface.
        float shell = abs(distance(world_point, dig_center_world) - dig_radius);
        float line = 1.0 - smoothstep(edge_width * 0.35, edge_width, shell);
        ALBEDO = mix(ALBEDO, ring_color.rgb, line);
        EMISSION = ring_color.rgb * (2.0 * line);
    }
}
