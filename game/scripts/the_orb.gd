extends MeshInstance3D

@onready var target_position := position
var accumulated_time := 0.0

func _process(delta: float) -> void:
	position.y = target_position.y + sin(accumulated_time * 2) * 0.1
	accumulated_time += delta
