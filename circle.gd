extends Polygon2D

@export var radius := 20.0
@export var segments := 20
@export var offset_x := 120.0

func _ready():
	var pts := []
	for i in segments:
		var a := TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)

	polygon = pts
	position = Vector2(offset_x, 0)
