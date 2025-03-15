extends RigidBody3D

const BULLET_SPEED = 100.0

var player
var PID

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	queue_free()
	print("This bullet is real.")
	
func set_pid(pid) -> void:
	PID = pid

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _integrate_forces(_state):
	linear_velocity = transform.basis.z * BULLET_SPEED
	
func _on_area_3d_body_entered(body: Node3D) -> void:
	pass
	#var isPeer = false
	#var peers = multiplayer.get_peers()
	#
	#for peer in peers:
		#if str(peer) == body.name:
			#isPeer = true
			#
	#if str(PID) != body.name and isPeer:
		#var main = get_tree().root.get_child(0)
		#main.hit_body(body.name)
		#queue_free()
