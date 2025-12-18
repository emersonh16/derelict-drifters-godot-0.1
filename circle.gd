extends Polygon2D

@export var radius := 20.0
@export var segments := 20

func _ready():
	var pts := []
	for i in range(segments):
		var a = TAU * i / segments
		pts.append(Vector2(cos(a), sin(a)) * radius)
	polygon = pts
