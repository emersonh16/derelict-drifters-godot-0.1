extends Node2D

@export var fog_color := Color(1, 1, 1, 0.85)

@onready var miasma := get_parent()


func _process(_delta):
	var cam := get_viewport().get_camera_2d()
	if not miasma or not cam:
		return

	var vp := get_viewport_rect().size
	var half_world := (vp * 0.5) * cam.zoom
	var top_left := cam.global_position - half_world

	# Anchor this node to the camera’s top-left in WORLD space (correct under zoom)
	global_position = top_left

	queue_redraw()


func _draw():
	if not miasma:
		return

	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var tile_size: int = miasma.tile_size
	var vp := get_viewport_rect().size
	
	var overscan := 2.0   # render 2x viewport in world space

	var center := cam.global_position
	var half_world_os := (vp * 0.5) * cam.zoom * overscan

	var sample_min := center - half_world_os
	var sample_max := center + half_world_os

	var start_x := int(floor(sample_min.x / tile_size))
	var start_y := int(floor(sample_min.y / tile_size))
	var end_x := int(ceil(sample_max.x / tile_size))
	var end_y := int(ceil(sample_max.y / tile_size))

	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			var world_pos := Vector2(x, y) * tile_size
			if not miasma.is_fog_at_world(world_pos):
				continue

			var local := world_pos - global_position

			# Isometric projection (2:1)
			var iso_x := (local.x - local.y) * 0.5
			var iso_y := (local.x + local.y) * 0.25

			var half_w := tile_size * 0.5
			var half_h := tile_size * 0.25

			var pts := PackedVector2Array([
				Vector2(iso_x,           iso_y - half_h),
				Vector2(iso_x + half_w,  iso_y),
				Vector2(iso_x,           iso_y + half_h),
				Vector2(iso_x - half_w,  iso_y),
			])

			draw_polygon(pts, PackedColorArray([fog_color]))
