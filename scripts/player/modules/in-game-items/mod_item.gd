extends Node3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

@export var mod = preload("res://scenes/player/modules/gun_mod.tscn")
@export var mod_name = "gun_mod"

var main
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	main = get_tree().current_scene
	if main == null and get_tree().root.get_child_count() > 0:
		main = get_tree().root.get_child(0)
	mod = mod.instantiate()
	animation_player.current_animation = "hover"


func _on_area_3d_body_entered(body: Node3D) -> void:
	# If not connected yet, ignore pickups
	if not multiplayer.multiplayer_peer:
		return
	if body.name == str(multiplayer.get_unique_id()):
		# return early if we already have the mod.
		for child in body.get_children():
			if child.name == mod.name: 
				print("We already have this mod!")
				return
		body.add_child(mod)
		# Tell the server about this pickup so it can sync to all peers
		# Also send the node path so the server can remove the pickup everywhere
		main.add_mod(mod_name, get_path())
		queue_free()
