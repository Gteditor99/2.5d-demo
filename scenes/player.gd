extends CharacterBody3D

#region Constants
const SPEED = 5.0
const JUMP_VELOCITY = 4.5
#endregion

#region Exported Variables
@export_group("Movement")
@export var acceleration: float = 30.0
@export var deceleration: float = 50.0

@export_group("Sprinting")
@export var sprint_speed_multiplier: float = 1.75
@export var sprint_bob_multiplier: float = 1.5 # Multiplier for bob when sprinting

@export_group("Crouching")
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_downward_offset: float = 0.5 # How much head moves down
@export var crouch_collision_height_standing: float = 1.8
@export var crouch_collision_height_crouching: float = 1.0
@export var crouch_transition_speed: float = 10.0

@export_group("Peeking")
@export var peek_offset_x: float = 0.4
@export var peek_rotation_z_degrees: float = 15.0
@export var peek_transition_speed: float = 12.0

@export_group("View")
@export var mouse_sensitivity: float = 0.002 # Radians per pixel
@export var pitch_limit_degrees: float = 80.0 # Max degrees up/down

@export_group("View Bobbing")
@export var bob_frequency: float = 3.0
@export var bob_amplitude: float = 0.1
@export var bob_amplitude_roll: float = 0.03
#endregion

#region Nodes
@onready var head_node: Node3D = $Head
@onready var collision_shape_node: CollisionShape3D = $CollisionShape3D
#endregion

#region Private Variables
# --- General ---
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _input_direction: Vector3 = Vector3.ZERO
var _current_speed: float = SPEED

# --- Player State ---
enum PlayerState {IDLE, WALKING, SPRINTING, JUMPING, CROUCHING, PEEKING_LEFT, PEEKING_RIGHT}
var _current_player_state: PlayerState = PlayerState.IDLE
var _is_sprinting: bool = false # Retained for direct input check, state will also reflect this
var _is_crouching: bool = false # Retained for direct input check
var _can_shoot: bool = true # Can be used to disable shooting temporarily
var _is_dead: bool = false # Player is dead, used for respawn logic TODO: integrate with state machine

# --- Camera ---
var _pitch_limit_radians: float
var _current_pitch: float = 0.0

# --- Head / View Bobbing ---
var _bob_time: float = 0.0
var _initial_head_y: float
var _initial_head_local_x: float
var _current_head_y_base: float # Base Y position for head, affected by crouching

# --- Crouching ---
var _standing_collider_y_pos: float
var _crouching_collider_y_pos: float

# --- Peeking ---
var _peek_target_offset_x: float = 0.0
var _peek_target_rotation_z_rad: float = 0.0
var _current_applied_peek_roll: float = 0.0
#endregion


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_pitch_limit_radians = deg_to_rad(pitch_limit_degrees)

	_initial_head_y = head_node.position.y
	_initial_head_local_x = head_node.position.x
	_current_head_y_base = _initial_head_y

	_setup_collision_shape()
	$CanvasLayer/GunBase/AnimatedSprite2D.animation_finished.connect(shoot_animation_done)


func _setup_collision_shape() -> void:
	if not collision_shape_node:
		push_error("Player CollisionShape3D node not found. Please assign it in the editor. Crouching will not affect collision.")
		return
	if not collision_shape_node.shape is CapsuleShape3D:
		push_error("Player CollisionShape3D node (" + str(collision_shape_node.name) + ") is not a CapsuleShape3D. Crouching will not affect collision.")
		collision_shape_node = null # Prevent further errors
		return

	var shape: CapsuleShape3D = collision_shape_node.shape
	if shape.height != crouch_collision_height_standing:
		push_warning("Initial CapsuleShape3D height (" + str(shape.height) + ") does not match crouch_collision_height_standing (" + str(crouch_collision_height_standing) + "). Ensure they are consistent or adjust export var.")
		# Optionally, force it: shape.height = crouch_collision_height_standing
	
	_standing_collider_y_pos = collision_shape_node.position.y
	# Calculate crouching collider Y pos based on height difference, assuming collider shrinks from top down
	_crouching_collider_y_pos = _standing_collider_y_pos - (crouch_collision_height_standing - crouch_collision_height_crouching) / 2.0


func _unhandled_input(event: InputEvent) -> void:
	var isMouseCaptured: bool = Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	if Input.is_action_just_pressed("mouse_capture_toggle") and isMouseCaptured:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE) # Toggle mouse visibility
	elif Input.is_action_just_pressed("mouse_capture_toggle") and not isMouseCaptured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		return
	if event is InputEventMouseMotion and isMouseCaptured:
		_handle_mouse_look(event)


func _physics_process(delta: float) -> void:
	_handle_input(delta)
	_update_player_state()
	_apply_gravity(delta)
	_apply_movement(delta)
	_update_crouch_visuals_and_collision(delta)
	_update_peek_visuals(delta)
	_update_head_bob(delta)
	
	move_and_slide()

#-----------------------------------------------------------------------------
#region Input Handling
#-----------------------------------------------------------------------------
func _handle_input(delta: float) -> void:
	_process_movement_input(delta)
	_process_jump_input(delta)
	# Peeking input is handled within _process_movement_input for now or can be separated
	# Mouse look is in _unhandled_input

func _process_movement_input(delta: float) -> void:
	# Sprinting
	if Input.is_action_just_pressed("sprint"):
		_is_sprinting = true
	elif Input.is_action_just_released("sprint"):
		_is_sprinting = false

	# Crouching
	if Input.is_action_just_pressed("crouch"):
		if _is_crouching: # Attempting to stand
			# Basic stand-up check: only allow standing if not trying to sprint (common conflict)
			# A proper check would involve a raycast or shape cast upwards.
			if not _is_sprinting: # Simple check: don't stand if also trying to sprint
				_is_crouching = false
		else: # Attempting to crouch
			_is_crouching = true
			_is_sprinting = false # Cannot sprint while crouching

	# Movement direction
	var input_strength_x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var input_strength_z = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward") # Forward is -Z
	_input_direction = (transform.basis * Vector3(input_strength_x, 0, input_strength_z)).normalized()

	# Peeking
	var is_peeking_left = Input.is_action_pressed("peek_left") and not _is_crouching # Can't peek while crouching
	var is_peeking_right = Input.is_action_pressed("peek_right") and not _is_crouching

	if is_peeking_left and not is_peeking_right:
		_peek_target_offset_x = - peek_offset_x
		_peek_target_rotation_z_rad = deg_to_rad(peek_rotation_z_degrees)
	elif is_peeking_right and not is_peeking_left:
		_peek_target_offset_x = peek_offset_x
		_peek_target_rotation_z_rad = deg_to_rad(-peek_rotation_z_degrees)
	else:
		_peek_target_offset_x = 0.0
		_peek_target_rotation_z_rad = 0.0

	# Shooting
	if Input.is_action_just_pressed("shoot"):
		shoot()

func _process_jump_input(delta: float) -> void:
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		velocity.y = JUMP_VELOCITY

func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	# Horizontal rotation (Yaw) - applied to the CharacterBody3D itself
	self.rotate_y(-event.relative.x * mouse_sensitivity)
	
	# Vertical rotation (Pitch) - applied to the Head node
	_current_pitch = clamp(_current_pitch - event.relative.y * mouse_sensitivity, -_pitch_limit_radians, _pitch_limit_radians)
	head_node.rotation.x = _current_pitch

func shoot() -> void:
	if !_can_shoot:
		return
	_can_shoot = false # Prevent further shooting until reset

	# Ensure the shoot animation doesn't loop, so "animation_finished" signal is emitted.
	$CanvasLayer/GunBase/AnimatedSprite2D.sprite_frames.set_animation_loop("shoot", false)
	$CanvasLayer/GunBase/AnimatedSprite2D.play("shoot")
	# sound
	if $RayCast3D.is_colliding() and $RayCast3D.get_collider().has_method("kill"):
		$RayCast3D.get_collider().kill()

func shoot_animation_done() -> void:
	_can_shoot = true # Allow shooting again after animation completes
	$CanvasLayer/GunBase/AnimatedSprite2D.play("idle") # Reset to idle animation

func kill() -> void:
	_is_dead = true
	$CanvasLayer/DeathScreen.show() # Show death screen
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	pass

#endregion

#-----------------------------------------------------------------------------
#region State Management
#-----------------------------------------------------------------------------
func _update_player_state() -> void:
	if not is_on_floor():
		_current_player_state = PlayerState.JUMPING
	elif _peek_target_offset_x != 0:
		_current_player_state = PlayerState.PEEKING_LEFT if _peek_target_offset_x < 0 else PlayerState.PEEKING_RIGHT
	elif _is_crouching:
		_current_player_state = PlayerState.CROUCHING
	elif _is_sprinting and _input_direction.length_squared() > 0.01:
		_current_player_state = PlayerState.SPRINTING
	elif _input_direction.length_squared() > 0.01:
		_current_player_state = PlayerState.WALKING
	else:
		_current_player_state = PlayerState.IDLE
#endregion

#-----------------------------------------------------------------------------
#region Physics & Movement
#-----------------------------------------------------------------------------
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta

func _apply_movement(delta: float) -> void:
	_current_speed = SPEED
	if _current_player_state == PlayerState.CROUCHING:
		_current_speed *= crouch_speed_multiplier
	elif _current_player_state == PlayerState.SPRINTING:
		# Ensure sprint conditions are met (e.g., on floor, moving)
		if is_on_floor() and _input_direction.length_squared() > 0.01: # Check for any horizontal movement
			_current_speed *= sprint_speed_multiplier
		else: # If not moving or in air, revert to walking speed even if sprint key is held
			_is_sprinting = false # Force sprint off if conditions not met
			# State will update in next _update_player_state call

	if _input_direction.length_squared() > 0.01:
		velocity.x = move_toward(velocity.x, _input_direction.x * _current_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, _input_direction.z * _current_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)
#endregion

#-----------------------------------------------------------------------------
#region Visual Updates (Crouch, Peek, Bob)
#-----------------------------------------------------------------------------
func _update_crouch_visuals_and_collision(delta: float) -> void:
	var target_collider_height = crouch_collision_height_crouching if _is_crouching else crouch_collision_height_standing
	var target_collider_y_pos = _crouching_collider_y_pos if _is_crouching else _standing_collider_y_pos
	var target_head_y_for_crouch = (_initial_head_y - crouch_downward_offset) if _is_crouching else _initial_head_y

	_current_head_y_base = lerp(_current_head_y_base, target_head_y_for_crouch, delta * crouch_transition_speed)

	if collision_shape_node: # Already checked for null and type in _setup_collision_shape
		var shape: CapsuleShape3D = collision_shape_node.shape
		shape.height = lerp(shape.height, target_collider_height, delta * crouch_transition_speed)
		collision_shape_node.position.y = lerp(collision_shape_node.position.y, target_collider_y_pos, delta * crouch_transition_speed)

func _update_peek_visuals(delta: float) -> void:
	head_node.position.x = lerp(head_node.position.x, _initial_head_local_x + _peek_target_offset_x, delta * peek_transition_speed)
	_current_applied_peek_roll = lerp(_current_applied_peek_roll, _peek_target_rotation_z_rad, delta * peek_transition_speed)
	# Head bobbing will add its roll to this

func _update_head_bob(delta: float) -> void:
	var bob_offset_roll_this_frame: float = 0.0
	var horizontal_velocity_sq = velocity.x * velocity.x + velocity.z * velocity.z # Use squared length

	# Bobbing only when on floor and moving, and not peeking (peeking has its own roll)
	if is_on_floor() and horizontal_velocity_sq > 1.0 and _current_player_state != PlayerState.PEEKING_LEFT and _current_player_state != PlayerState.PEEKING_RIGHT:
		var effective_bob_frequency = bob_frequency
		var effective_bob_amplitude = bob_amplitude
		var effective_bob_amplitude_roll = bob_amplitude_roll

		if _current_player_state == PlayerState.SPRINTING:
			# Example: Increase frequency and amplitude when sprinting
			# sprint_bob_multiplier could be a single value or a struct/dictionary for more control
			effective_bob_frequency *= sprint_bob_multiplier
			effective_bob_amplitude *= sprint_bob_multiplier
			effective_bob_amplitude_roll *= sprint_bob_multiplier
		
		_bob_time += delta * effective_bob_frequency # Scale bob time by frequency
		var bob_phase = _bob_time * 2.0 * PI # Bob time now directly relates to cycles via frequency adjustment
		
		var bob_offset_y = sin(bob_phase) * effective_bob_amplitude
		head_node.position.y = _current_head_y_base + bob_offset_y
		bob_offset_roll_this_frame = sin(bob_phase * 0.5) * effective_bob_amplitude_roll # Slower roll
	else:
		# Smoothly return to base position if not bobbing
		_bob_time = lerp(_bob_time, floor(_bob_time), delta * 15.0) # Smoothly reset phase towards an integer
		head_node.position.y = lerp(head_node.position.y, _current_head_y_base, delta * 20.0)
		# bob_offset_roll_this_frame remains 0.0
	
	# Combine peek roll and bob roll
	head_node.rotation.z = _current_applied_peek_roll + bob_offset_roll_this_frame
#endregion
