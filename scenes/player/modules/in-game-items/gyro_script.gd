extends Node3D
@onready var animation_player_6: Node3D = $AnimationPlayer6

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var i = 0
	print("test")
	for child in animation_player_6.get_children():
		child.current_animation="Spin" + str(i)
		i += 1
		child.active=true
		print(child)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
