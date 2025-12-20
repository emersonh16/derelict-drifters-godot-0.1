shader_type canvas_item;

uniform vec2 world_offset = vec2(0.0, 0.0);

void fragment() {
	COLOR = texture(TEXTURE, fract(UV + world_offset));
}
