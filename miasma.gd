extends Node2D

@onready var fog := get_parent().get_node("FogSprite")
var cam: Camera2D

func _ready():
	cam = get_viewport().get_camera_2d()

func _process(_delta):
	if cam:
		var mat := fog.material as ShaderMaterial
		mat.set_shader_parameter(
			"world_offset",
			cam.global_position * 0.001
		)
