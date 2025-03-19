extends TabContainer

@onready var main: Node3D = $"../../../.."
@onready var car_scenes = [ # in order of tabs in scene
	"res://addons/gevp/scenes/drift_car.tscn",
	"res://addons/gevp/scenes/monster_truck.tscn",
	"res://addons/gevp/scenes/simcade_car.tscn",
	"res://addons/gevp/scenes/arcade_car.tscn"
]
func _ready():
	_on_tab_selected(0)

# Callback when a tab is selected
func _on_tab_selected(tab: int) -> void:
	if car_scenes:
		main.set_car_scene(car_scenes[tab])
	# Iterate through the children of the TabContainer
	for i in range(get_child_count()):
		var child = get_child(i)
		# Check if the child is a valid control and not the currently selected tab
		if child is Control:
			child.visible = (i == tab)
			child.get_child(0).get_child(0).get_child(1).visible = (i == tab)
