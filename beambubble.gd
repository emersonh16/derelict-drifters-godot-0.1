extends Node2D

@export var bubble_tiles := 0
@export var MAX_BUBBLE_TILES := 12

# Submit clearing requests to miasma (intent-only, no mutation)
func _process(_delta):
	if bubble_tiles > 0:
		var miasma = get_tree().get_first_node_in_group("miasma")
		if miasma:
			miasma.submit_request("bubble", {
				"center_world": global_position,
				"bubble_tiles": float(bubble_tiles)
			})
