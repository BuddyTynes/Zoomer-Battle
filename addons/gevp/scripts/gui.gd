extends Control

@export var vehicle : Vehicle

@onready var speed_label = $VBoxContainer/Speed
@onready var rpm_label = $VBoxContainer/RPM
@onready var gear_label = $VBoxContainer/Gear

var respawn_timer: Timer
var respawn_label: Label
var score_label: Label
var health_bg: ColorRect
var health_fill: ColorRect
var shield_bg: ColorRect
var shield_fill: ColorRect
var _health_ratio := 1.0
var _shield_ratio := 0.0
const _BAR_WIDTH := 220.0
const _BAR_HEIGHT := 14.0

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
	_create_bars()
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

func set_health_shield(health: int, max_health: int, shield: int, max_shield: int) -> void:
	_health_ratio = 0.0 if max_health <= 0 else clampf(float(health) / float(max_health), 0.0, 1.0)
	_shield_ratio = 0.0 if max_shield <= 0 else clampf(float(shield) / float(max_shield), 0.0, 1.0)
	_update_bars()

func _create_bars() -> void:
	# Health bar
	health_bg = ColorRect.new()
	health_bg.color = Color(0, 0, 0, 0.6)
	health_bg.anchor_left = 0.0
	health_bg.anchor_top = 0.0
	health_bg.anchor_right = 0.0
	health_bg.anchor_bottom = 0.0
	health_bg.offset_left = 16
	health_bg.offset_top = 16
	health_bg.offset_right = 16 + _BAR_WIDTH
	health_bg.offset_bottom = 16 + _BAR_HEIGHT
	add_child(health_bg)

	health_fill = ColorRect.new()
	health_fill.color = Color(0.86, 0.2, 0.2, 1)
	health_fill.anchor_left = 0.0
	health_fill.anchor_top = 0.0
	health_fill.anchor_right = 0.0
	health_fill.anchor_bottom = 0.0
	health_fill.offset_left = 0
	health_fill.offset_top = 0
	health_fill.offset_right = _BAR_WIDTH
	health_fill.offset_bottom = _BAR_HEIGHT
	health_bg.add_child(health_fill)

	# Shield bar
	shield_bg = ColorRect.new()
	shield_bg.color = Color(0, 0, 0, 0.6)
	shield_bg.anchor_left = 0.0
	shield_bg.anchor_top = 0.0
	shield_bg.anchor_right = 0.0
	shield_bg.anchor_bottom = 0.0
	shield_bg.offset_left = 16
	shield_bg.offset_top = 36
	shield_bg.offset_right = 16 + _BAR_WIDTH
	shield_bg.offset_bottom = 36 + _BAR_HEIGHT
	add_child(shield_bg)

	shield_fill = ColorRect.new()
	shield_fill.color = Color(0.2, 0.55, 0.95, 1)
	shield_fill.anchor_left = 0.0
	shield_fill.anchor_top = 0.0
	shield_fill.anchor_right = 0.0
	shield_fill.anchor_bottom = 0.0
	shield_fill.offset_left = 0
	shield_fill.offset_top = 0
	shield_fill.offset_right = _BAR_WIDTH
	shield_fill.offset_bottom = _BAR_HEIGHT
	shield_bg.add_child(shield_fill)

func _update_bars() -> void:
	if health_fill:
		health_fill.offset_right = _BAR_WIDTH * _health_ratio
	if shield_fill:
		shield_fill.offset_right = _BAR_WIDTH * _shield_ratio
