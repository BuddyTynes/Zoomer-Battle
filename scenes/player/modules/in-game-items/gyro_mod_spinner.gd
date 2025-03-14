extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("in ready!!!")
	$AnimationPlayer.current_animation = "Action"
	$AnimationPlayer.active = true
