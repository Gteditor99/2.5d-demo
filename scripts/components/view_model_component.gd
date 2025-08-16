@tool
class_name ViewModelComponent
extends Node

## This component manages the weapon's view model, handling transitions
## between states like idle, sprinting, and aiming (ADS).

enum State {IDLE, SPRINTING, AIMING}

# Signals for recoil debug system
signal recoil_started()
signal recoil_progress_updated(progress: float)
signal recoil_history_updated(positional_history: Array, rotational_history: Array)

@export_group("Dependencies")
var weapon_node: Node3D
@export var camera: Camera3D

var _weapon_system_component: Node
var _weapon_data: WeaponData
var _target_position: Vector3
var _target_rotation: Vector3
var _current_position: Vector3
var _current_rotation: Vector3
var _target_fov: float
var _transition_speed: float = 10.0
var _is_first_state_set: bool = false
var _recoil_offset: Vector3
var _recoil_recovery_speed: float
var _current_state: State = State.IDLE

var _positional_recoil_velocity: Vector3
var _rotational_recoil_velocity: Vector3
var _positional_recoil_offset: Vector3
var _rotational_recoil_offset: Vector3
var _recoil_time: float = 0.0
var _is_recording_recoil: bool = false
var _recoil_history_positional: Array = []
var _recoil_history_rotational: Array = []


func _ready():
	# Add to group for easy discovery by debug systems
	add_to_group("view_model")
	
	var weapon_nodes = get_tree().get_nodes_in_group("Weapon")
	if weapon_nodes.size() > 0:
		weapon_node = weapon_nodes[0] as Node3D

func _process(delta: float) -> void:
	if not weapon_node or not camera:
		return

	# Smoothly interpolate the weapon's position, rotation, and camera's FOV
	var target_rotation_rad = Vector3(deg_to_rad(_target_rotation.x), deg_to_rad(_target_rotation.y), deg_to_rad(_target_rotation.z))

	if not _weapon_data: return
	
	_current_position = _current_position.lerp(_target_position, delta * _transition_speed)
	_current_rotation = _current_rotation.lerp(target_rotation_rad, delta * _transition_speed)
	
	# Apply recoil system
	var recoil_data = _weapon_data.recoil_data
	if recoil_data:
		# Update recoil time
		if _is_recording_recoil:
			_recoil_time += delta
			
			# Calculate progress (0 to 1)
			var recoil_duration = 1.0 # Assuming a 1-second recoil duration for now
			var progress = clamp(_recoil_time / recoil_duration, 0.0, 1.0)
			
			# Emit progress signal every frame
			emit_signal("recoil_progress_updated", progress)
			
			# Stop recording after duration
			if _recoil_time >= recoil_duration:
				_is_recording_recoil = false
				Debug.log("ViewModelComponent: Recoil completed, emitting history")
				emit_signal("recoil_history_updated", _recoil_history_positional, _recoil_history_rotational)
		
		# Apply spring-based physics for smooth recoil animation
		var positional_spring_force = - recoil_data.positional_stiffness * _positional_recoil_offset - recoil_data.positional_damping * _positional_recoil_velocity
		_positional_recoil_velocity += positional_spring_force * delta
		_positional_recoil_offset += _positional_recoil_velocity * delta

		var rotational_spring_force = - recoil_data.rotational_stiffness * _rotational_recoil_offset - recoil_data.rotational_damping * _rotational_recoil_velocity
		_rotational_recoil_velocity += rotational_spring_force * delta
		_rotational_recoil_offset += _rotational_recoil_velocity * delta
		
		# Apply curve-based recoil modulation (limited time range)
		var curve_time = clamp(_recoil_time, 0.0, 1.0) # Limit curve sampling to 0-1 range
		
		# Sample positional curves and apply as force multipliers (not additive)
		if recoil_data.positional_recoil_curve_x and recoil_data.positional_recoil_curve_y and recoil_data.positional_recoil_curve_z:
			var pos_curve_x = recoil_data.positional_recoil_curve_x.sample(curve_time)
			var pos_curve_y = recoil_data.positional_recoil_curve_y.sample(curve_time)
			var pos_curve_z = recoil_data.positional_recoil_curve_z.sample(curve_time)
			
			# Apply curve values as additional velocity (not position offset)
			_positional_recoil_velocity.x += pos_curve_x * delta * 0.5
			_positional_recoil_velocity.y += pos_curve_y * recoil_data.positional_kick_up * delta
			_positional_recoil_velocity.z += pos_curve_z * recoil_data.positional_kick_back * delta

		# Sample rotational curves and apply as force multipliers
		if recoil_data.rotational_recoil_curve_x and recoil_data.rotational_recoil_curve_y and recoil_data.rotational_recoil_curve_z:
			var rot_curve_x = recoil_data.rotational_recoil_curve_x.sample(curve_time)
			var rot_curve_y = recoil_data.rotational_recoil_curve_y.sample(curve_time)
			var rot_curve_z = recoil_data.rotational_recoil_curve_z.sample(curve_time)
			
			# Apply curve values as additional velocity
			_rotational_recoil_velocity.x += rot_curve_x * recoil_data.rotational_kick_up * delta
			_rotational_recoil_velocity.y += rot_curve_y * delta * 0.3
			_rotational_recoil_velocity.z += rot_curve_z * recoil_data.rotational_kick_back * delta

		weapon_node.position = _current_position + _positional_recoil_offset
		weapon_node.rotation = _current_rotation + _rotational_recoil_offset
		
		if _is_recording_recoil:
			_recoil_history_positional.append(_positional_recoil_offset)
			_recoil_history_rotational.append(_rotational_recoil_offset)
	else:
		weapon_node.position = _current_position
		weapon_node.rotation = _current_rotation

	camera.fov = lerp(camera.fov, _target_fov, delta * _transition_speed)


func apply_recoil():
	if not _weapon_data or not _weapon_data.recoil_data:
		return
	
	var recoil_data = _weapon_data.recoil_data
	_recoil_recovery_speed = recoil_data.recovery_speed
	
	# Reset recoil time for new shot
	_recoil_time = 0.0
	_is_recording_recoil = true
	_recoil_history_positional.clear()
	_recoil_history_rotational.clear()
	
	# Emit recoil started signal
	emit_signal("recoil_started")
	emit_signal("recoil_progress_updated", 0.0)
	
	# Determine ADS multipliers based on current state
	var pos_multiplier = 1.0
	var rot_multiplier = 1.0
	var is_aiming = (_current_state == State.AIMING)
	
	if is_aiming:
		pos_multiplier = recoil_data.ads_positional_multiplier
		rot_multiplier = recoil_data.ads_rotational_multiplier
	
	# Apply randomness to kick forces
	var random_x = randf_range(-recoil_data.randomness, recoil_data.randomness)
	var random_y = randf_range(-recoil_data.randomness, recoil_data.randomness)
	var random_z = randf_range(-recoil_data.randomness, recoil_data.randomness)
	
	# Generate stronger horizontal randomness for more unpredictable sway
	var horizontal_random = randf_range(-1.0, 1.0) # Full range random for left/right direction
	var horizontal_intensity = randf_range(0.5, 1.5) # Random intensity multiplier
	
	# Apply initial kick forces as velocity impulses with ADS multipliers
	# Enhanced horizontal positional recoil with dedicated kick force
	_positional_recoil_velocity.x += recoil_data.positional_kick_horizontal * horizontal_random * horizontal_intensity * pos_multiplier
	_positional_recoil_velocity.y += recoil_data.positional_kick_up * (1.0 + random_y) * pos_multiplier
	_positional_recoil_velocity.z += recoil_data.positional_kick_back * (1.0 + random_z) * pos_multiplier
	
	# Enhanced horizontal rotational recoil with dedicated kick force
	_rotational_recoil_velocity.x += recoil_data.rotational_kick_up * (1.0 + random_x) * rot_multiplier
	_rotational_recoil_velocity.y += recoil_data.rotational_kick_horizontal * horizontal_random * horizontal_intensity * rot_multiplier
	_rotational_recoil_velocity.z += recoil_data.rotational_kick_back * (1.0 + random_z) * rot_multiplier

func set_state(new_state: State, weapon_data: WeaponData) -> void:
	if not weapon_data:
		return

	# Store current state for ADS detection
	_current_state = new_state

	match new_state:
		State.IDLE:
			_target_position = weapon_data.idle_view_offset
			_target_rotation = weapon_data.idle_view_rotation
			_target_fov = weapon_data.idle_fov
			_transition_speed = weapon_data.idle_transition_speed
		State.SPRINTING:
			_target_position = weapon_data.sprint_view_offset
			_target_rotation = weapon_data.sprint_view_rotation
			_target_fov = weapon_data.sprint_fov
			_transition_speed = weapon_data.sprint_transition_speed
		State.AIMING:
			_target_position = weapon_data.ads_view_offset
			_target_rotation = weapon_data.ads_view_rotation
			_target_fov = weapon_data.ads_fov
			_transition_speed = weapon_data.ads_transition_speed
	
	if not _is_first_state_set:
		_current_position = _target_position
		_current_rotation = Vector3(deg_to_rad(_target_rotation.x), deg_to_rad(_target_rotation.y), deg_to_rad(_target_rotation.z))
		_is_first_state_set = true

func set_weapon_node(node: Node3D):
	weapon_node = node
	Debug.log("RECOIL: set_weapon_node called with: %s" % [node != null])

func set_weapon_system_component(node: Node):
	_weapon_system_component = node
	_weapon_data = node.weapon_data
	Debug.log("RECOIL: set_weapon_system_component called - weapon_data: %s" % [_weapon_data != null])
