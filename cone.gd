extends Polygon2D

@export var length := 120.0
@export var width := 40.0

func _ready():
	polygon = [
		Vector2.ZERO,
		Vector2(length, -width * 0.5),
		Vector2(length,  width * 0.5),
	]
