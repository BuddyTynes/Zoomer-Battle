extends Resource
class_name EngineResource

@export var max_rpm: float = 7000.00
@export var max_power: float = 250.0
@export var gears: Array[int] = [1, 2, 3, 4, 5, 6]
@export var gear_ratios: Array[float] = [3.8, 2.2, 1.5, 1.0, 0.8, 0.6]
@export var wheel_size: float = 0.5
@export var idle_RPM: float = 1100.00

var current_gear: int = 1
var current_rpm: float = 0.00
var throttle: float = 0.0


func get_power(wheel_rpm: float, input: float) -> Array:
	self.throttle = clamp(input, 0.0, 1.0)  # Ensure throttle is between 0 and 1
	var gear_ratio = gear_ratios[current_gear - 1]
	current_rpm = wheel_rpm * gear_ratio  # Engine RPM based on wheel RPM and gear
	var ranNum = randf_range(-100, 100)
	current_rpm += idle_RPM + ranNum
	# Gear shifting logic
	if current_rpm > max_rpm * 0.7 and current_gear < gears.size():
		shift_up()
		gear_ratio = gear_ratios[current_gear - 1]
		current_rpm = wheel_rpm * gear_ratio  # Recalculate RPM after shifting
	elif current_rpm <= 1100 and current_gear >= 1:
		shift_down()
		gear_ratio = gear_ratios[current_gear - 1]
		current_rpm = wheel_rpm * gear_ratio  # Recalculate RPM after shifting
	# Prevent division by zero or unrealistic low RPM
	current_rpm = max(current_rpm, 1.0)
	
	# Calculate engine power with a simplified torque curve
	var rpm_factor = current_rpm / max_rpm
	var torque_factor = 1.0 - pow(1.0 - rpm_factor, 2)  # Peaks near max_rpm, drops off
	var engine_power = max_power * throttle * torque_factor
	
	return [clamp(engine_power, 0, max_power), current_rpm]


func shift_up(amount = 1) -> void:
	if current_gear + amount <= gears.size():
		current_gear += amount

func shift_down(amount = 1) -> void:
	if current_gear - amount > 0:
		current_gear -= amount

func get_current_rpm() -> float:
	return current_rpm

func get_current_gear() -> int:
	return current_gear
