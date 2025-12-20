extends TileMapLayer

# Which tile to paint for fog (TileSet source + atlas coords)
@export var fog_source_id: int = 0
@export var fog_atlas: Vector2i = Vector2i(0, 0)
@export var buffer_tiles := 24
@export var forget_buffer_tiles := 24
@export var regrow_interval := 0.5
@export var regrow_chance := 0.25

var filled := {}
var _regrow_timer := 0.0
var last_center := Vector2i(999999, 999999)

# Cells we have "carved out" (world-anchored)
var cleared := {} # Dictionary: Vector2i -> true
var _regrow_index := 0


func _ready():
	add_to_group("miasma")


func _physics_process(_delta):
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return
	
	var center := local_to_map(to_local(cam.global_position))
	


	_regrow_timer += _delta
	if _regrow_timer >= regrow_interval:
		_regrow_timer = 0.0
		_try_regrow(center)


	var viewport_size := cam.get_viewport_rect().size
	var tile_size := tile_set.tile_size

	var radius_x := int(ceil(viewport_size.x / tile_size.x)) + buffer_tiles
	var radius_y := int(ceil(viewport_size.y / tile_size.y)) + buffer_tiles
	var forget_radius_x := radius_x + forget_buffer_tiles
	var forget_radius_y := radius_y + forget_buffer_tiles

	if last_center.x > 900000:
		last_center = center
		_fill_fog_rect(center, radius_x, radius_y, forget_radius_x, forget_radius_y)
		return

	
	if center == last_center:
		return

	var prev_center := last_center
	var delta := center - prev_center
	last_center = center


	if delta.x != 0:
		var step: int = sign(delta.x)
		for i in range(abs(delta.x)):
			var y: int = prev_center.y + step * (radius_y - i)
			var x: int = prev_center.x + step * (radius_x - i)
			var cell := Vector2i(x, y)
			if not cleared.has(cell) and not filled.has(cell):

					set_cell(cell, fog_source_id, fog_atlas)
					filled[cell] = true

	if delta.y != 0:
		var step: int = sign(delta.y)
		for i in range(abs(delta.y)):
			var y: int = prev_center.y + step * (radius_y - i)
			for x in range(center.x - radius_x, center.x + radius_x + 1):
				var cell := Vector2i(x, y)
				if not cleared.has(cell) and not filled.has(cell):
					set_cell(cell, fog_source_id, fog_atlas)
					filled[cell] = true



func _fill_fog_rect(center: Vector2i, radius_x: int, radius_y: int, forget_radius_x: int, forget_radius_y: int) -> void:
	for y in range(center.y - radius_y, center.y + radius_y + 1):
		for x in range(center.x - radius_x, center.x + radius_x + 1):
			var cell := Vector2i(x, y)
			if cleared.has(cell) or filled.has(cell):
				continue
			set_cell(cell, fog_source_id, fog_atlas)
			filled[cell] = true


	for cell in cleared.keys():
		if abs(cell.x - center.x) > forget_radius_x or abs(cell.y - center.y) > forget_radius_y:
			cleared.erase(cell)
			filled.erase(cell)



# (We will use this in Step 2/3)
func clear_fog_at_world(world_pos: Vector2) -> void:
	var cell := local_to_map(to_local(world_pos))
	cleared[cell] = true
	filled.erase(cell)
	set_cell(cell, -1)



func _try_regrow(center: Vector2i) -> void:
	var keys: Array = cleared.keys()
	if keys.is_empty():
		return

	var steps: int = max(1, int(keys.size() * 0.1))
	for i in range(steps):
		var cell: Vector2i = keys[_regrow_index % keys.size()] as Vector2i
		_regrow_index += 1
		if randf() > regrow_chance:
			continue



		var neighbors := [
			cell + Vector2i.LEFT,
			cell + Vector2i.RIGHT,
			cell + Vector2i.UP,
			cell + Vector2i.DOWN,
		]

		for n in neighbors:
			if not cleared.has(n):
				cleared.erase(cell)
				set_cell(cell, fog_source_id, fog_atlas)
				break
