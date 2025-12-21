extends Node2D

@export var visible_in_editor := true

@export var LASER_MIN_LENGTH_TILES := 10.0
@export var LASER_MAX_LENGTH_TILES := 22.0

@export var LASER_MIN_HALF_WIDTH_TILES := 0.35
@export var LASER_MAX_HALF_WIDTH_TILES := 0.90

@export var CORE_WIDTH_SCALE := 0.35

const MIASMA_TILE_X := 16.0

func _process(_delta):
	var cone := _get_cone()
	if cone:
		visible = (cone.focus >= 0.95)
	
	if not visible_in_editor and Engine.is_editor_hint():
		visible = false
	
	if visible:
		queue_redraw()
		
		# Submit clearing request (intent-only, no mutation)
		var miasma = get_tree().get_first_node_in_group("miasma")
		if miasma and cone:
			miasma.submit_request("laser", {
				"origin_world": global_position,
				"aim_angle": cone.aim_angle,
				"focus": clamp(cone.focus, 0.0, 1.0)
			})


func _draw():
	var cone := _get_cone()
	if not cone:
		return

	# Safety check: do not draw if focus is below the handoff threshold
	if cone.focus < 0.95:
		return

	var aim_angle: float = cone.aim_angle
	var focus: float = clamp(cone.focus, 0.0, 1.0)

	var length_px: float = lerp(
		LASER_MIN_LENGTH_TILES * MIASMA_TILE_X,
		LASER_MAX_LENGTH_TILES * MIASMA_TILE_X,
		focus
	)

	var half_w_px: float = lerp(
		LASER_MIN_HALF_WIDTH_TILES * MIASMA_TILE_X,
		LASER_MAX_HALF_WIDTH_TILES * MIASMA_TILE_X,
		focus
	)

	var origin_td := Vector2.ZERO
	var dir_td := Vector2.RIGHT.rotated(aim_angle)
	var perp_td := dir_td.orthogonal().normalized()

	var p0 := origin_td
	var p1 := origin_td + dir_td * length_px

	var a := IsoMath.to_iso(p0 + perp_td * half_w_px)
	var b := IsoMath.to_iso(p0 - perp_td * half_w_px)
	var c := IsoMath.to_iso(p1 - perp_td * half_w_px)
	var d := IsoMath.to_iso(p1 + perp_td * half_w_px)

	draw_colored_polygon([a, b, c, d], Color(1, 0.8, 0.2, 0.35))

	var core_half_w := half_w_px * CORE_WIDTH_SCALE
	var a2 := IsoMath.to_iso(p0 + perp_td * core_half_w)
	var b2 := IsoMath.to_iso(p0 - perp_td * core_half_w)
	var c2 := IsoMath.to_iso(p1 - perp_td * core_half_w)
	var d2 := IsoMath.to_iso(p1 + perp_td * core_half_w)

	draw_colored_polygon([a2, b2, c2, d2], Color(1.0, 0.8, 0.2, 1.0))

func _get_cone() -> Node:
	if not get_parent():
		return null
	return get_parent().get_node_or_null("BeamCone")
	
	
func laser_hits_point_topdown(p: Vector2) -> bool:
	if not visible:
		return false

	var cone := _get_cone()
	if not cone: return false
	var t: float = clamp(cone.focus, 0.0, 1.0)

	var length_px: float = lerp(
		LASER_MIN_LENGTH_TILES,
		LASER_MAX_LENGTH_TILES,
		t
	) * MIASMA_TILE_X

	var radius_px: float = lerp(
		LASER_MIN_HALF_WIDTH_TILES,
		LASER_MAX_HALF_WIDTH_TILES,
		t
	) * MIASMA_TILE_X

	var origin := global_position
	var dir := Vector2.RIGHT.rotated(global_rotation)

	var a := origin
	var b := origin + dir * length_px

	var ab := b - a
	var ap := p - a

	var ab_len_sq := ab.length_squared()
	if ab_len_sq == 0.0:
		return false

	var u: float = clamp(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * u

	return p.distance_to(closest) <= radius_px


func laser_hits_circle_topdown(p: Vector2, r: float) -> bool:
	if not visible:
		return false

	var t: float = clamp(get_parent().focus, 0.0, 1.0)

	var length_px: float = lerp(
		LASER_MIN_LENGTH_TILES,
		LASER_MAX_LENGTH_TILES,
		t
	) * MIASMA_TILE_X

	var radius_px: float = (
		lerp(
			LASER_MIN_HALF_WIDTH_TILES,
			LASER_MAX_HALF_WIDTH_TILES,
			t
		) * MIASMA_TILE_X
	) + r

	var origin := global_position
	var dir := Vector2.RIGHT.rotated(global_rotation)

	var a := origin
	var b := origin + dir * length_px

	var ab := b - a
	var ap := p - a

	var ab_len_sq := ab.length_squared()
	if ab_len_sq == 0.0:
		return false

	var u: float = clamp(ap.dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = a + ab * u

	return p.distance_to(closest) <= radius_px
