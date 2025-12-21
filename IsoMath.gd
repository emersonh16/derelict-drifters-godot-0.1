extends Node
# This script is stateless. Per DDGDD.md, it handles projection only.

const ISO_Y_SCALE := 0.5

## Converts Top-Down (Gameplay Truth) to Isometric (Visuals)
func to_iso(v: Vector2) -> Vector2:
	return Vector2(v.x - v.y, (v.x + v.y) * ISO_Y_SCALE)

## Converts Isometric back to Top-Down
## Corrected inversion: Solving td.x - td.y = iso.x and (td.x + td.y) * 0.5 = iso.y
func from_iso(iso: Vector2) -> Vector2:
	var x_truth = (iso.x + (iso.y / ISO_Y_SCALE)) * 0.5
	var y_truth = ((iso.y / ISO_Y_SCALE) - iso.x) * 0.5
	return Vector2(x_truth, y_truth)
