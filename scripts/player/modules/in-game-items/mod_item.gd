extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var mod = preload("res://scenes/player/modules/gun_mod.tscn")
@export var mod_name = "gun_mod"

var main
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main = get_tree().root.get_child(0)
	mod = mod.instantiate()
	animation_player.current_animation = "hover"

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == str(multiplayer.get_unique_id()):
		# return early if we already have the mod.
		for child in body.get_children():
			if child.name == mod.name: 
				print("We already have this mod!")
				return
		body.add_child(mod)
		main.add_mod(mod_name)
		queue_free()
