extends Node2D

@onready var fog := get_parent().get_node("FogSprite")
var cam: Camera2D

@export var fog_size := Vector2i(256, 256)

var fog_image: Image
var fog_texture: ImageTexture
var fog_dirty := false

func world_to_iso(p: Vector2) -> Vector2:
	return Vector2(
		p.x - p.y,
		(p.x + p.y) * 0.5
	)

func _ready():
	add_to_group("miasma")
	cam = get_viewport().get_camera_2d()

	fog_image = Image.create(
		fog_size.x,
		fog_size.y,
		false,
		Image.FORMAT_RGBA8
	)
	fog_image.fill(Color(0.6, 0.0, 0.6, 0.85))
	fog_texture = ImageTexture.create_from_image(fog_image)
	fog.texture = fog_texture



		
var last_center_cell := Vector2i.ZERO
@export var cell_size := 32

func _process(_delta):
	if not cam:
		return


	var mat := fog.material as ShaderMaterial
	mat.set_shader_parameter(
		"world_offset",
		world_to_iso(cam.global_position) * 0.001
	)

	var center_cell := Vector2i(
		floor(cam.global_position.x / cell_size),
		floor(cam.global_position.y / cell_size)
	)

	if center_cell != last_center_cell:
		last_center_cell = center_cell
	
	clear_at_world(cam.global_position, 6)
	if fog_dirty:
		fog_texture.update(fog_image)
		fog_dirty = false

func clear_at_world(world_pos: Vector2, radius := 6):
	print("CLEAR", world_pos)
	var iso_world := world_to_iso(world_pos)
	var iso_cam := world_to_iso(cam.global_position)
	var tex_pos := (iso_world - iso_cam) + Vector2(fog_size) * 0.5

	var cx := int(tex_pos.x)
	var cy := int(tex_pos.y)

	for y in range(-radius, radius + 1):
		for x in range(-radius, radius + 1):
			if x * x + y * y > radius * radius:
				continue

			var px := cx + x
			var py := cy + y

			if px < 0 or py < 0 or px >= fog_size.x or py >= fog_size.y:
				continue

			fog_image.set_pixel(px, py, Color(1, 1, 1, 0))

	fog_dirty = true
