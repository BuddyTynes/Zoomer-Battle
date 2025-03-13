extends Node3D

@onready var vehicle: Vehicle = $".."

const SHOOT_INTERVAL = 0.1 # Time between shots in seconds
const BULLET_SPEED = 1000.0  # Speed of the bullets

@onready var left_gun_position = $"gun-2/gun-tip"
@onready var right_gun_position = $"gun-1/gun-tip"
@onready var bullet_scene = preload("res://scenes/player/modules/bullet.tscn")

var time_since_last_shot = 0.0
var right = false
var pid

func _ready() -> void:
	pid = multiplayer.get_unique_id()
	
func _process(delta: float) -> void:
	if Input.is_action_pressed("fire_guns"):
		time_since_last_shot += delta
		if time_since_last_shot >= SHOOT_INTERVAL:
			time_since_last_shot = 0.0
			shoot_guns()

func shoot_guns() -> void:
	var bullet = bullet_scene.instantiate()
	var gun_pos = right_gun_position if right == true else left_gun_position
	right = !right
	# set and spawn
	bullet.transform.origin = gun_pos.global_transform.origin
	bullet.transform.basis = gun_pos.global_transform.basis
	bullet.linear_velocity = gun_pos.global_transform.basis.z * BULLET_SPEED
	bullet.set_pid(pid) # check which PID bullet is fired from
	get_tree().root.add_child(bullet)
