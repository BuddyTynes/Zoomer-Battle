extends Node3D

const MAX_SUCTION_FORCE = 300.0
const SUCTION_FORCE_INCREMENT = 100.0

@onready var vehicle: Vehicle = $".."

var suction_force := 0.0
var is_suction_active := false

func _process(delta: float) -> void:
	if Input.is_action_pressed("jump_or_clamp"):
		# Suction Force Logic
		is_suction_active = true
		suction_force += SUCTION_FORCE_INCREMENT * delta
		if suction_force > MAX_SUCTION_FORCE:
			suction_force = MAX_SUCTION_FORCE
		apply_clamp_force()
	elif Input.is_action_just_released("jump_or_clamp") and is_suction_active:
		is_suction_active = false
		apply_jump_force()

func apply_jump_force() -> void:
	var suction_vector = suction_force * transform.basis.y
	vehicle.apply_impulse(suction_vector * 100, Vector3.ZERO)
	suction_force = 0.0
	
func apply_clamp_force() -> void:
	var suction_vector = -suction_force * transform.basis.y
	vehicle.apply_impulse(suction_vector, Vector3.ZERO)
