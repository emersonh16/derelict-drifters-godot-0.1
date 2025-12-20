extends TileMapLayer

# Which tile to paint for fog (TileSet source + atlas coords)
@export var fog_source_id: int = 0
@export var fog_atlas: Vector2i = Vector2i(0, 0)
@export var buffer_tiles := 24
@export var forget_buffer_tiles := 24
var cleared_cells := {}


var last_center := Vector2i(999999, 999999)

# Cells we have "carved out" (world-anchored)
var cleared := {} # Dictionary: Vector2i -> true

func _ready():
	add_to_group("miasma")


func _physics_process(_delta):
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return

	var center := local_to_map(to_local(cam.global_position))

	var viewport_size := cam.get_viewport_rect().size
	var tile_size := tile_set.tile_size

	var radius_x := int(ceil(viewport_size.x / tile_size.x)) + buffer_tiles
	var radius_y := int(ceil(viewport_size.y / tile_size.y)) + buffer_tiles

	var forget_radius_x := radius_x + forget_buffer_tiles
	var forget_radius_y := radius_y + forget_buffer_tiles

	
	if center == last_center:
		return

	last_center = center
	_fill_fog_rect(center, radius_x, radius_y, forget_radius_x, forget_radius_y)


func _fill_fog_rect(center: Vector2i, radius_x: int, radius_y: int, forget_radius_x: int, forget_radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var cell := Vector2i(x, y)
			if cleared.has(cell):
				continue
			set_cell(cell, fog_source_id, fog_atlas)

	for cell in cleared.keys():
		if abs(cell.x - center.x) > forget_radius_x or abs(cell.y - center.y) > forget_radius_y:
			cleared.erase(cell)


# (We will use this in Step 2/3)
func clear_fog_at_world(world_pos: Vector2) -> void:
	var cell := local_to_map(to_local(world_pos))
	cleared[cell] = true
	set_cell(cell, -1)
