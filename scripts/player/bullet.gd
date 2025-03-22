extends RigidBody3D

const BULLET_SPEED = 100.0

var player
var PID

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	queue_free()
	
func set_pid(pid) -> void:
	PID = pid

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _integrate_forces(_state):
	linear_velocity = transform.basis.z * BULLET_SPEED
	
func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group("Hittable") and body.name != PID:
		if  multiplayer.is_server():
			var main = get_tree().root.get_child(0)
			main.hit_body(body.name, PID)
		if body.name != "VehicleRigidBody":
			$trail.process_material.radial_velocity_max = 60
			$MeshInstance3D.hide()
			await get_tree().create_timer(.1).timeout
			
		queue_free()
