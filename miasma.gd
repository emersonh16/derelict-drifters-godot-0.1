extends Node2D

@onready var fog := get_parent().get_node("FogSprite")
var cam: Camera2D

@export var fog_size := Vector2i(256, 256)

var fog_image: Image
var fog_texture: ImageTexture

func _ready():
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

	fog.global_position = cam.global_position

	var mat := fog.material as ShaderMaterial
	mat.set_shader_parameter("world_offset", cam.global_position * 0.001)

	var center_cell := Vector2i(
		floor(cam.global_position.x / cell_size),
		floor(cam.global_position.y / cell_size)
	)

	if center_cell != last_center_cell:
		last_center_cell = center_cell
		fog_image.fill(Color(0.6, 0.0, 0.6, 0.85))
		fog_texture.update(fog_image)
