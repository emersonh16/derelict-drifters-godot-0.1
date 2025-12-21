extends RefCounted
class_name IsoMath

const ISO_Y_SCALE := 0.5

static func td_to_iso(v: Vector2) -> Vector2:
	return Vector2(v.x - v.y, (v.x + v.y) * ISO_Y_SCALE)

static func iso_to_td(v: Vector2) -> Vector2:
	var sum := v.y / ISO_Y_SCALE
	return Vector2(
		(v.x + sum) * 0.5,
		(sum - v.x) * 0.5
	)
