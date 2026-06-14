extends Node3D

@onready var mesh = $Mesh
@onready var collision_shape = $StaticBody3D/CollisionShape3D

var direction := Vector3.ZERO
var speed := 0.0
var drag := 0.0
var life_time := 0.0
var counter := 0.0

var rotation_x := (randf() * 2 - 1) * 5
var rotation_y := (randf() * 2 - 1) * 5
var rotation_z := (randf() * 2 - 1) * 5

func _physics_process(delta: float) -> void:
	counter += delta

	position += direction * speed * delta
	
	speed *= 1 - drag

	mesh.rotation.x += rotation_x * delta
	mesh.rotation.y += rotation_y * delta
	mesh.rotation.z += rotation_z * delta

	var query = PhysicsShapeQueryParameters3D.new()
	query.shape = collision_shape.shape
	query.transform = global_transform
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = true

	var space_state = get_world_3d().direct_space_state

	if space_state.intersect_shape(query):
		queue_free()

	if counter >= life_time:
		queue_free()
