extends Node2D

@export var bubble_tiles := 6
const ISO_Y_SCALE := 0.5

const MIASMA_TILE_X := 16.0
const MIASMA_TILE_Y := 8.0

@onready var miasma = get_tree().get_first_node_in_group("miasma")



func _ready():
	queue_redraw()

func _unhandled_input(event):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			bubble_tiles += 1
			queue_redraw()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			bubble_tiles = max(1, bubble_tiles - 1)
			queue_redraw()

func _draw():
	# CRITICAL: cancel node rotation so shape is ground-locked
	draw_set_transform(
		Vector2.ZERO,
		-global_rotation,
		Vector2.ONE
	)

	var rx := bubble_tiles * MIASMA_TILE_X
	var ry := bubble_tiles * MIASMA_TILE_Y

	var steps := 48
	var pts := PackedVector2Array()

	for i in range(steps):
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))

	draw_colored_polygon(pts, Color(1, 1, 0, 0.25))
	_draw_debug_tiles()
	
	
func _draw_debug_tiles():
	if not miasma:
		return

	var center_world := global_position
	var center_cell: Vector2i = miasma.local_to_map(miasma.to_local(center_world))


	var r_tiles_x := bubble_tiles
	var r_tiles_y := int(ceil(bubble_tiles * (MIASMA_TILE_X / MIASMA_TILE_Y)))
	var rx := bubble_tiles * MIASMA_TILE_X
	var ry := bubble_tiles * MIASMA_TILE_Y

	for dy in range(-r_tiles_y, r_tiles_y + 1):
		for dx in range(-r_tiles_x, r_tiles_x + 1):

			# exact match: test in bubble local space
			var cell := center_cell + Vector2i(dx, dy)
			var world_pos: Vector2 = miasma.to_global(
				miasma.map_to_local(cell)
			)

			var local := to_local(world_pos)

			if (
				(local.x * local.x) / (rx * rx) +
				(local.y * local.y) / (ry * ry)
			) > 1.0:
				continue



func _clear_miasma():
	if not miasma:
		return

	var center_world := global_position
	var center_cell: Vector2i = miasma.local_to_map(miasma.to_local(center_world))

	var r_tiles_x := bubble_tiles
	var r_tiles_y := int(ceil(bubble_tiles * (MIASMA_TILE_X / MIASMA_TILE_Y)))

	var rx := bubble_tiles * MIASMA_TILE_X
	var ry := bubble_tiles * MIASMA_TILE_Y

	for dy in range(-r_tiles_y, r_tiles_y + 1):
		for dx in range(-r_tiles_x, r_tiles_x + 1):
			var cell := center_cell + Vector2i(dx, dy)
			var world_pos: Vector2 = miasma.to_global(
				miasma.map_to_local(cell)
			)

			var local := to_local(world_pos)

			if (
				(local.x * local.x) / (rx * rx) +
				(local.y * local.y) / (ry * ry)
			) > 1.0:
				continue

			miasma.clear_fog_at_world(world_pos)
			

func _process(_delta):
	_clear_miasma()
