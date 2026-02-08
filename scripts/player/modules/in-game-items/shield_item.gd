extends Node3D

@export var shield_amount := 40

var main

func _ready() -> void:
	main = get_tree().current_scene
	if main == null and get_tree().root.get_child_count() > 0:
		main = get_tree().root.get_child(0)

func _on_area_3d_body_entered(body: Node3D) -> void:
	if not multiplayer.multiplayer_peer:
		return
	if body.name == str(multiplayer.get_unique_id()):
		if main and main.has_method("add_shield_pickup"):
			main.add_shield_pickup(shield_amount, get_path())
		queue_free()
