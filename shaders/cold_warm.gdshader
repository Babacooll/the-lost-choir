shader_type canvas_item;

// Art-direction doc §4.1's cold-derive transform + §4.2's warmth field.
// Assets are authored warm only (the node's own color/texture = the warm
// albedo); this shader derives the cold appearance at runtime rather than
// reading a hand-painted cold asset. Constants mirror
// docs/art/palettes/lost-choir-slice.json exactly — change there first, this
// shader second, per that doc's "art-direction contract" rule.

// Set per-instance by WarmthVisual: 0.0 before the wavefront arrives, up to
// 1.15 in the leading-edge overshoot band, settling back to 1.0 behind it.
instance uniform float w = 0.0;
// Brass takes a different derive path (§4.1) and is the only material the
// overshoot band is allowed to show as emission.
instance uniform bool is_brass = false;

const float DESAT_DEFAULT = 0.72;
const float DESAT_BRASS = 0.55;
const vec3 TINT_DEFAULT = vec3(0.88, 0.96, 1.08);
const vec3 TINT_BRASS = vec3(0.92, 0.97, 1.03);
const vec3 COLD_MID = vec3(57.0 / 255.0, 66.0 / 255.0, 79.0 / 255.0); // #39424f
const float COLD_MID_AMOUNT = 0.18;
const float BRASS_UNLIT_SCALE = 0.82;

vec3 derive_cold(vec3 warm) {
	float luma = dot(warm, vec3(0.2126, 0.7152, 0.0722));
	float s = is_brass ? DESAT_BRASS : DESAT_DEFAULT;
	vec3 desat = mix(warm, vec3(luma), s);
	vec3 tint = is_brass ? TINT_BRASS : TINT_DEFAULT;
	vec3 tinted = desat * tint;
	if (is_brass) {
		// Unlit, not repainted: full value structure kept, just scaled down.
		return tinted * BRASS_UNLIT_SCALE;
	}
	return mix(tinted, COLD_MID, COLD_MID_AMOUNT);
}

void fragment() {
	vec4 warm = texture(TEXTURE, UV) * COLOR;
	vec3 cold = derive_cold(warm.rgb);

	// Albedo clamps at w=1 for everyone — the overshoot band never brightens
	// the base material past its warm value.
	vec3 rendered = mix(cold, warm.rgb, clamp(w, 0.0, 1.0));

	if (is_brass) {
		// "In the cold state the world's warmth lives in reflectance only;
		// not one pixel of it is emitted" (§4.1) — so overshoot only ever
		// adds emission on brass, additively, never on the derived albedo.
		float overshoot = max(w - 1.0, 0.0);
		rendered += warm.rgb * overshoot;
	}

	COLOR = vec4(rendered, warm.a);
}
