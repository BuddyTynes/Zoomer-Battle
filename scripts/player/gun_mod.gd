extends Node3D

@onready var vehicle: Vehicle = $".."

const SHOOT_INTERVAL = 0.1 # Time between shots in seconds
const BULLET_SPEED = 1000.0  # Speed of the bullets

@onready var left_gun_position = $"gun-2/gun-tip"
@onready var right_gun_position = $"gun-1/gun-tip"
@onready var bullet_scene = preload("res://scenes/player/modules/bullet.tscn")

var time_since_last_shot = 0.0
var right = false

func _process(delta: float) -> void:
	if Input.is_action_pressed("fire_guns"):
		time_since_last_shot += delta
		if time_since_last_shot >= SHOOT_INTERVAL:
			time_since_last_shot = 0.0
			shoot_guns()

func shoot_guns() -> void:
	if right == true:
		right = false
		var right_bullet = bullet_scene.instantiate()
		right_bullet.transform.origin = right_gun_position.global_transform.origin
		right_bullet.transform.basis = right_gun_position.global_transform.basis
		right_bullet.linear_velocity = right_gun_position.global_transform.basis.z * BULLET_SPEED
		get_tree().root.add_child(right_bullet)
	else:
		right = true
		var left_bullet = bullet_scene.instantiate()
		left_bullet.transform.origin = left_gun_position.global_transform.origin
		left_bullet.transform.basis = left_gun_position.global_transform.basis
		left_bullet.linear_velocity = left_gun_position.global_transform.basis.z * BULLET_SPEED
		get_tree().root.add_child(left_bullet)
