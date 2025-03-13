extends RigidBody3D

const BULLET_SPEED = 100.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	queue_free()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _integrate_forces(_state):
	linear_velocity = transform.basis.z * BULLET_SPEED
