@onready var beam = $Beam

func _process(delta):
	var mouse_pos = get_global_mouse_position()
	var dir = mouse_pos - global_position
	beam.rotation = dir.angle()

	beam.visible = Input.is_action_pressed("attack")
