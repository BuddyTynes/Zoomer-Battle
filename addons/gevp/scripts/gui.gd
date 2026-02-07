extends Control

@export var vehicle : Vehicle

@onready var speed_label = $VBoxContainer/Speed
@onready var rpm_label = $VBoxContainer/RPM
@onready var gear_label = $VBoxContainer/Gear

var respawn_timer: Timer
var respawn_label: Label
var score_label: Label

func _process(delta):
	if not is_instance_valid(vehicle):
		speed_label.text = ""
		rpm_label.text = ""
		gear_label.text = ""
		return
	speed_label.text = str(round(vehicle.speed * 3.6)) + " km/h"
	rpm_label.text = str(round(vehicle.motor_rpm)) + " rpm"
	gear_label.text = "Gear: " + str(vehicle.current_gear)

func _ready() -> void:
	score_label = Label.new()
	score_label.name = "Score"
	score_label.text = "Kills: 0  Deaths: 0"
	score_label.anchor_left = 0.0
	score_label.anchor_right = 0.0
	score_label.anchor_top = 1.0
	score_label.anchor_bottom = 1.0
	score_label.offset_left = 16
	score_label.offset_right = 260
	score_label.offset_top = -48
	score_label.offset_bottom = -16
	add_child(score_label)
	# Build a simple respawn label at the top-center
	respawn_label = Label.new()
	respawn_label.name = "RespawnLabel"
	respawn_label.visible = false
	respawn_label.text = ""
	respawn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	respawn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	respawn_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	respawn_label.size_flags_vertical = Control.SIZE_EXPAND
	respawn_label.anchor_left = 0.0
	respawn_label.anchor_right = 1.0
	respawn_label.anchor_top = 0.0
	respawn_label.anchor_bottom = 0.0
	# Godot 4 uses offsets instead of margins
	respawn_label.offset_top = 40
	add_child(respawn_label)

	respawn_timer = Timer.new()
	respawn_timer.one_shot = true
	add_child(respawn_timer)

func start_respawn_countdown(seconds: int) -> void:
	# Show countdown locally for the player
	respawn_label.visible = true
	await _run_countdown(seconds)
	# Keep visible state until complete_respawn hides it

func _run_countdown(seconds: int) -> void:
	var t = seconds
	while t > 0:
		respawn_label.text = "Respawning in " + str(t)
		respawn_timer.start(1.0)
		await respawn_timer.timeout
		t -= 1
	respawn_label.text = "Respawning..."

func hide_respawn() -> void:
	respawn_label.visible = false
	respawn_label.text = ""

func set_score(kills: int, deaths: int) -> void:
	if score_label:
		score_label.text = "Kills: %s  Deaths: %s" % [str(kills), str(deaths)]
