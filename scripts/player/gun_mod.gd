extends Node3D


@export var bullet_scene: PackedScene

const SHOOT_INTERVAL = 0.1 # Time between shots in seconds
const BULLET_SPEED = 1000.0  # Speed of the bullets

@onready var vehicle: Vehicle = $".."
@onready var left_gun_position = $"gun-2/gun-tip"
@onready var right_gun_position = $"gun-1/gun-tip"

var timer = Timer.new()
var time_since_last_shot = 0.0
var right = false
var pid
var main

func _ready() -> void:
	pid = vehicle.name
	main = get_tree().root.get_child(0)
	# we will tell the server that we need to sync mods after timer
	timer.wait_time = 2.0  # Set the time in seconds
	timer.one_shot = true  # Stops after one cycle
	add_child(timer)  # Add the timer to the scene tree
	timer.start()  # Start the timer
	timer.connect("timeout", Callable(self, "_add_mod_on_clients"))
	
func _process(delta: float) -> void:
	if Input.is_action_pressed("fire_guns") and main and str(multiplayer.get_unique_id()) == vehicle.name:
		time_since_last_shot += delta
		if time_since_last_shot >= SHOOT_INTERVAL:
			time_since_last_shot = 0.0
			shoot_guns()
			main.spawn_bullet()

func shoot_guns() -> void:
	var bullet = bullet_scene.instantiate()
	var gun_pos = right_gun_position if right == true else left_gun_position
	right = !right
	# set and spawn
	bullet.transform.origin = gun_pos.global_transform.origin
	bullet.transform.basis = gun_pos.global_transform.basis
	bullet.linear_velocity = gun_pos.global_transform.basis.z * BULLET_SPEED
	bullet.set_pid(pid) # check which PID bullet is fired from
	main.get_child(1).add_child(bullet)
	
func _add_mod_on_clients():
	pid = vehicle.name #re-assign here after 2 seconds so spawning mods can have correct PID
	main.add_mod("gun_mod")
	
