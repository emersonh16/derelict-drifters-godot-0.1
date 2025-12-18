extends Polygon2D

@onready var hitbox := $"../Hitbox"

@export var length := 120.0
@export var width := 40.0

func _ready():
	var pts = [
		Vector2(0, 0),
		Vector2(length, -width * 0.5),
		Vector2(length,  width * 0.5),
	]

	polygon = pts
	hitbox.polygon = pts
