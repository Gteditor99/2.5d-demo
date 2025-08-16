extends CharacterBody3D

#region Player-Specific Exports (Visuals, Camera, etc.)
@export_group("Sprinting")
@export var sprint_speed_multiplier: float = 1.75
@export var sprint_bob_multiplier: float = 1.5

@export_group("Crouching")
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_downward_offset: float = 0.5
@export var crouch_collision_height_standing: float = 1.8
@export var crouch_collision_height_crouching: float = 1.0
@export var crouch_transition_speed: float = 10.0

@export_group("Peeking")
@export var peek_offset_x: float = 0.4
@export var peek_rotation_z_degrees: float = 15.0
@export var peek_transition_speed: float = 12.0

@export_group("View")
@export var mouse_sensitivity: float = 0.002
@export var pitch_limit_degrees: float = 80.0

@export_group("View Bobbing")
@export var bob_frequency: float = 3.0
@export var bob_amplitude: float = 0.1
@export var bob_amplitude_roll: float = 0.03
#endregion
#region Stair Stepping Constants
const STAIRS_FEELING_COEFFICIENT: float = 2.5
const SPEED_CLAMP_AFTER_JUMP_COEFFICIENT = 0.4
#endregion

#region Nodes
# @onready var head_node: Node3D = $Head
@onready var head_node = $Head
@onready var collision_shape_node: CollisionShape3D = $CollisionShape3D
@onready var gun_raycast: RayCast3D = $Head/RayCast3D
var gun_anim_sprite: AnimationPlayer
var barrel_node: Node3D
var weapon_instance: Node3D
var _recoil_debug_menu_instance: PanelContainer
const RecoilDebugMenu = preload("res://scenes/ui/recoil_debug/recoil_debug_menu.tscn")
#endregion
# --- Components ---
@onready var movement_component: MovementComponent = $MovementComponent
@onready var health_component: HealthComponent = $HealthComponent
@onready var stair_stepping_component: StairSteppingComponent = $StairSteppingComponent
@onready var weapon_system_component: WeaponSystemComponent = $WeaponSystemComponent
@onready var view_model_component: ViewModelComponent = $ViewModelComponent

#endregion

#region Private Variables
# --- Player State ---
enum PlayerState {IDLE, WALKING, SPRINTING, JUMPING, CROUCHING, PEEKING_LEFT, PEEKING_RIGHT, AIMING}
var _current_player_state: PlayerState = PlayerState.IDLE
var _is_sprinting: bool = false
var _is_crouching: bool = false
var _is_aiming: bool = false

# --- Camera ---
var _pitch_limit_radians: float
var _current_pitch: float = 0.0
@export var WASD_TILT_DEGREES = 15.0
@export var TILT_SMOOTHING_SPEED = 10.0 # Adjust this value for tilt smoothing speed
var _wasd_tilt: float = 0.0
@export var TILT_REVERSAL_DELAY = 2.0 # Time in seconds before tilt reverses
var _movement_duration = 0.0
var _is_tilt_returning = false

# --- Head / View Bobbing ---
var _bob_time: float = 0.0
var _initial_head_y: float
var _initial_head_local_x: float
var _current_head_y_base: float
var _current_bob_amplitude: float = 0.0
var _current_bob_amplitude_roll: float = 0.0

# --- Crouching ---
var _standing_collider_y_pos: float
var _crouching_collider_y_pos: float

# --- Peeking ---
var _peek_target_offset_x: float = 0.0
var _peek_target_rotation_z_rad: float = 0.0
var _current_applied_peek_roll: float = 0.0
var _head_offset: Vector3 = Vector3.ZERO

# --- Stair Stepping ---
var was_on_floor: bool = false
var is_jumping: bool = false
var is_in_air: bool = false

# --- Movement State ---
var direction: Vector3 = Vector3.ZERO
var main_velocity: Vector3 = Vector3.ZERO
var gravity_direction: Vector3 = Vector3.ZERO
var movement: Vector3 = Vector3.ZERO
#endregion


func _ready() -> void:
	print("Player ready")
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_pitch_limit_radians = deg_to_rad(pitch_limit_degrees)

	_initial_head_y = head_node.position.y
	_initial_head_local_x = head_node.position.x
	_current_head_y_base = _initial_head_y

	_setup_collision_shape()
	
	# Instantiate and setup weapon
	if weapon_system_component and weapon_system_component.weapon_data and weapon_system_component.weapon_data.weapon_scene:
		weapon_instance = weapon_system_component.weapon_data.weapon_scene.instantiate()
		head_node.add_child(weapon_instance)
		weapon_instance.position = weapon_system_component.weapon_data.idle_view_offset
		var initial_rotation_deg = weapon_system_component.weapon_data.idle_view_rotation
		weapon_instance.rotation = Vector3(deg_to_rad(initial_rotation_deg.x), deg_to_rad(initial_rotation_deg.y), deg_to_rad(initial_rotation_deg.z))
		
		# Find nodes within the instantiated weapon scene
		var anim_players = weapon_instance.find_children("*", "AnimationPlayer", true, false)
		if not anim_players.is_empty():
			gun_anim_sprite = anim_players[0]
		else:
			gun_anim_sprite = null

		barrel_node = weapon_instance.find_child("spawnpoint", true, false)
		if not barrel_node:
			push_warning("Barrel node ('spawnpoint') not found in the weapon scene. Projectiles may not spawn correctly.")

		# Sync animation speed with fire rate
		if gun_anim_sprite:
			var anim = gun_anim_sprite.get_animation("animation")
			if anim:
				var fire_rate = weapon_system_component.weapon_data.rounds_per_minute / 60.0
				var anim_length = anim.length
				gun_anim_sprite.speed_scale = anim_length * fire_rate
		else:
			push_error("AnimationPlayer not found in the weapon scene.")

	# Setup ViewModelComponent
	if view_model_component:
		view_model_component.camera = $Head/Camera3D
		view_model_component.weapon_node = weapon_instance

	# Connect to the health component's died signal
	health_component.died.connect(_on_death)
	
	# Connect to the weapon system component's weapon_fired signal
	if weapon_system_component:
		weapon_system_component.weapon_fired.connect(_on_weapon_fired)


func _on_weapon_fired():
	if gun_anim_sprite and gun_anim_sprite.has_animation("animation"):
		gun_anim_sprite.play("animation")


func _setup_collision_shape() -> void:
	if not collision_shape_node or not collision_shape_node.shape is CylinderShape3D:
		push_error("Player requires a CollisionShape3D with a CapsuleShape3D.")
		return

	var shape: CylinderShape3D = collision_shape_node.shape
	_standing_collider_y_pos = collision_shape_node.position.y
	_crouching_collider_y_pos = _standing_collider_y_pos - (crouch_collision_height_standing - crouch_collision_height_crouching) / 2.0


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("debug"):
		Debug.log("Debug action pressed")
		toggle_recoil_debug_menu()

	if Input.is_action_just_pressed("mouse_capture_toggle"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_handle_mouse_look(event)


func _process(delta: float) -> void:
	if not health_component or health_component.current_health <= 0:
		return # Stop processing if dead
	
	# Handle all camera/visual updates at display refresh rate
	_update_wasd_tilt(delta)
	_update_crouch_visuals(delta)
	_update_peek_visuals(delta)
	_update_head_bob(delta)
	_update_stair_head_offset(delta)


func _physics_process(delta: float) -> void:
	if not health_component or health_component.current_health <= 0:
		return # Stop processing if dead


	_handle_input()
	_update_player_state()
	_handle_direct_movement(delta)
	_update_crouch_collision(delta)


#-----------------------------------------------------------------------------
#region Input & State
#-----------------------------------------------------------------------------
func _handle_input() -> void:
	# Aiming
	_is_aiming = Input.is_action_pressed("aim")

	# Sprinting
	_is_sprinting = Input.is_action_pressed("sprint") and not _is_aiming # Cannot sprint while aiming

	# Crouching
	if Input.is_action_just_pressed("crouch"):
		_is_crouching = not _is_crouching
		if _is_crouching:
			_is_sprinting = false # Cannot sprint while crouching

	# Jumping
	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		movement_component.jump()

	# Weapon Input
	weapon_system_component.handle_input()
		

func toggle_recoil_debug_menu():
	print("Toggling recoil debug menu.")
	if not _recoil_debug_menu_instance:
		print("Creating new recoil debug menu instance.")
		_recoil_debug_menu_instance = RecoilDebugMenu.instantiate()
		get_tree().get_root().add_child(_recoil_debug_menu_instance)
		_recoil_debug_menu_instance.recoil_data = weapon_system_component.weapon_data.recoil_data
		_recoil_debug_menu_instance.visible = true
		print("Recoil data assigned: ", _recoil_debug_menu_instance.recoil_data)
	else:
		_recoil_debug_menu_instance.visible = not _recoil_debug_menu_instance.visible
		print("Toggling visibility to: ", _recoil_debug_menu_instance.visible)
		if _recoil_debug_menu_instance.visible:
			_recoil_debug_menu_instance.recoil_data = weapon_system_component.weapon_data.recoil_data
			print("Recoil data reassigned: ", _recoil_debug_menu_instance.recoil_data)


func _update_player_state() -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var is_peeking = Input.is_action_pressed("peek_left") or Input.is_action_pressed("peek_right")

	if not is_on_floor():
		_current_player_state = PlayerState.JUMPING
	elif _is_aiming:
		_current_player_state = PlayerState.AIMING
	elif is_peeking and not _is_crouching:
		_current_player_state = PlayerState.PEEKING_LEFT if Input.is_action_pressed("peek_left") else PlayerState.PEEKING_RIGHT
	elif _is_crouching:
		_current_player_state = PlayerState.CROUCHING
	elif _is_sprinting and input_dir.length_squared() > 0.01:
		_current_player_state = PlayerState.SPRINTING
	elif input_dir.length_squared() > 0.01:
		_current_player_state = PlayerState.WALKING
	else:
		_current_player_state = PlayerState.IDLE
	_update_viewmodel_state()
#endregion

#-----------------------------------------------------------------------------
#region Movement & Actions
#-----------------------------------------------------------------------------
func _handle_direct_movement(delta: float) -> void:
	var input = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	direction = (global_transform.basis * Vector3(input.x, 0, input.y)).normalized()

	# Calculate speed based on state
	var current_speed = movement_component.SPEED
	if _current_player_state == PlayerState.SPRINTING:
		current_speed *= sprint_speed_multiplier
	elif _current_player_state == PlayerState.CROUCHING:
		current_speed *= crouch_speed_multiplier

	if is_on_floor():
		is_jumping = false
		was_on_floor = true
		gravity_direction = Vector3.ZERO
	else:
		was_on_floor = false
		gravity_direction += Vector3.DOWN * ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		is_jumping = true
		gravity_direction = Vector3.UP * movement_component.JUMP_VELOCITY

	main_velocity = main_velocity.lerp(direction * current_speed, movement_component.ACCELERATION * delta)

	var step_result: StairSteppingComponent.StepResult = stair_stepping_component.check_for_stairs(direction, was_on_floor)
	var is_step = step_result.diff_position != Vector3.ZERO

	if is_step:
		# The component now handles the position change. We just need to handle the consequences.
		_head_offset = step_result.diff_position
	else:
		_head_offset = _head_offset.lerp(Vector3.ZERO, delta * current_speed * STAIRS_FEELING_COEFFICIENT)

	movement = main_velocity + gravity_direction

	set_velocity(movement)
	set_max_slides(6)
	move_and_slide()

	if is_step and step_result.is_step_up:
		if not is_on_floor() or direction.dot(step_result.normal) > 0:
			# This logic for clamping velocity should be reviewed.
			# For now, we replicate the original behavior.
			main_velocity *= SPEED_CLAMP_AFTER_JUMP_COEFFICIENT
			gravity_direction *= SPEED_CLAMP_AFTER_JUMP_COEFFICIENT

	if is_jumping:
		is_jumping = false


func _update_wasd_tilt(delta: float) -> void:
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var target_tilt = 0.0
	
	if is_on_floor() and (input_dir.x != 0):
		_movement_duration += delta
		if _movement_duration >= TILT_REVERSAL_DELAY:
			_is_tilt_returning = true
			
		if not _is_tilt_returning:
			target_tilt = - input_dir.x * deg_to_rad(WASD_TILT_DEGREES)
		else:
			target_tilt = 0.0
		_movement_duration = 0.0
		_is_tilt_returning = false
	
	_wasd_tilt = lerp(_wasd_tilt, target_tilt, TILT_SMOOTHING_SPEED * delta)

func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	self.rotate_y(-event.relative.x * mouse_sensitivity)
	_current_pitch = clamp(_current_pitch - event.relative.y * mouse_sensitivity, -_pitch_limit_radians, _pitch_limit_radians)
	head_node.rotation.x = _current_pitch


func _on_death() -> void:
	print("Player has died.")
	$CanvasLayer/DeathScreen.show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# Disable further processing by stopping the physics process, or set a flag.
	set_physics_process(false)
#endregion

#-----------------------------------------------------------------------------
#region Visual Updates
#-----------------------------------------------------------------------------
func _update_crouch_visuals(delta: float) -> void:
	var target_head_y_for_crouch = (_initial_head_y - crouch_downward_offset) if _is_crouching else _initial_head_y
	_current_head_y_base = lerp(_current_head_y_base, target_head_y_for_crouch, delta * crouch_transition_speed)


func _update_crouch_collision(delta: float) -> void:
	var target_collider_height = crouch_collision_height_crouching if _is_crouching else crouch_collision_height_standing
	var target_collider_y_pos = _crouching_collider_y_pos if _is_crouching else _standing_collider_y_pos

	if collision_shape_node:
		var shape: CylinderShape3D = collision_shape_node.shape
		shape.height = lerp(shape.height, target_collider_height, delta * crouch_transition_speed)
		collision_shape_node.position.y = lerp(collision_shape_node.position.y, target_collider_y_pos, delta * crouch_transition_speed)


func _update_peek_visuals(delta: float) -> void:
	var is_peeking_left = Input.is_action_pressed("peek_left") and not _is_crouching
	var is_peeking_right = Input.is_action_pressed("peek_right") and not _is_crouching

	if is_peeking_left:
		_peek_target_offset_x = - peek_offset_x
		_peek_target_rotation_z_rad = deg_to_rad(peek_rotation_z_degrees)
	elif is_peeking_right:
		_peek_target_offset_x = peek_offset_x
		_peek_target_rotation_z_rad = deg_to_rad(-peek_rotation_z_degrees)
	else:
		_peek_target_offset_x = 0.0
		_peek_target_rotation_z_rad = 0.0
		
	head_node.position.x = lerp(head_node.position.x, _initial_head_local_x + _peek_target_offset_x, delta * peek_transition_speed)
	_current_applied_peek_roll = lerp(_current_applied_peek_roll, _peek_target_rotation_z_rad, delta * peek_transition_speed)


func _update_head_bob(delta: float) -> void:
	var bob_offset_roll_this_frame: float = 0.0
	var horizontal_velocity_sq = velocity.x * velocity.x + velocity.z * velocity.z
	var is_moving_on_floor = is_on_floor() and horizontal_velocity_sq > 0.01
	var target_bob_amplitude = 0.0
	var target_bob_amplitude_roll = 0.0

	if is_moving_on_floor and _current_player_state != PlayerState.PEEKING_LEFT and _current_player_state != PlayerState.PEEKING_RIGHT:
		var effective_bob_frequency = bob_frequency
		var effective_bob_amplitude = bob_amplitude
		var effective_bob_amplitude_roll = bob_amplitude_roll

		if _current_player_state == PlayerState.SPRINTING:
			effective_bob_frequency *= sprint_bob_multiplier
			effective_bob_amplitude *= sprint_bob_multiplier
			effective_bob_amplitude_roll *= sprint_bob_multiplier
		
		target_bob_amplitude = effective_bob_amplitude
		target_bob_amplitude_roll = effective_bob_amplitude_roll
		_bob_time += delta * effective_bob_frequency
	
	# Smoothly interpolate the bob amplitude values
	_current_bob_amplitude = lerp(_current_bob_amplitude, target_bob_amplitude, delta * 10.0)
	_current_bob_amplitude_roll = lerp(_current_bob_amplitude_roll, target_bob_amplitude_roll, delta * 10.0)

	# Apply the bobbing effect if the amplitude is significant
	if _current_bob_amplitude > 0.001:
		var bob_phase = _bob_time * 2.0 * PI
		var bob_offset_y = sin(bob_phase) * _current_bob_amplitude
		head_node.position.y = _current_head_y_base + bob_offset_y
		bob_offset_roll_this_frame = sin(bob_phase * 0.5) * _current_bob_amplitude_roll
	else:
		# When not bobbing, smoothly return to the base head position
		head_node.position.y = lerp(head_node.position.y, _current_head_y_base, delta * 20.0)

	head_node.rotation.z = _current_applied_peek_roll + bob_offset_roll_this_frame + _wasd_tilt

func _update_stair_head_offset(delta: float) -> void:
	# Smoothly lerp the head offset to reduce jarring stair stepping
	var target_offset = _head_offset.y
	var current_head_y = head_node.position.y - _current_head_y_base
	var smooth_offset = lerp(current_head_y, target_offset, delta * 8.0)
	head_node.position.y = _current_head_y_base + smooth_offset


#endregion

func _update_viewmodel_state() -> void:
	if not view_model_component:
		return
		
	var weapon_data = weapon_system_component.weapon_data
	if not weapon_data:
		return

	match _current_player_state:
		PlayerState.AIMING:
			view_model_component.set_state(ViewModelComponent.State.AIMING, weapon_data)
		PlayerState.SPRINTING:
			view_model_component.set_state(ViewModelComponent.State.SPRINTING, weapon_data)
		_:
			view_model_component.set_state(ViewModelComponent.State.IDLE, weapon_data)


func get_barrel_node() -> Node3D:
	return barrel_node
