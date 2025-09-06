class_name MovementComponent
extends Node

## component responsible for the movement of a CharacterBody3D parent
## handles movement, acceleration, friction, gravity, and jumping

# EXPORTED VARIABLES
@export var SPEED: float = 5.0
@export var ACCELERATION: float = 8.0
@export var FRICTION: float = 10.0
@export var JUMP_VELOCITY: float = 4.5


@export_group("Stair Handling")
@export var stair_stepping_component: StairSteppingComponent

@export_group("Equipment")
@export var equipment_component: EquipmentComponent

# PRIVATE VARIABLES
var _parent_body: CharacterBody3D
var _input_direction: Vector2 = Vector2.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _speed_multiplier: float = 1.0


func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D
	if not _parent_body:
		push_error("MovementComponent must be a child of a CharacterBody3D node.")
		set_physics_process(false)
		return

func _physics_process(delta: float) -> void:
	if not _parent_body:
		return
	var velocity: Vector3 = _parent_body.velocity

	# apply gravity
	if not _parent_body.is_on_floor():
		velocity.y -= _gravity * delta

	# calculate input direction based on the parent's orientation
	var direction: Vector3 = (_parent_body.transform.basis * Vector3(_input_direction.x, 0, _input_direction.y)).normalized()

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * SPEED * _speed_multiplier, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * SPEED * _speed_multiplier, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		velocity.z = move_toward(velocity.z, 0, FRICTION * delta)

	# --- Stair Check using intended velocity ---
	# set the final velocity on the parent body and call move_and_slide
	_parent_body.velocity = velocity
	_parent_body.move_and_slide()
	
	# reset input direction for the next frame
	_input_direction = Vector2.ZERO


# PUBLIC METHODS
func set_input_direction(direction: Vector2) -> void:
	"""Sets the input direction for movement.
	The direction should be a normalized Vector2 where:
	- (1, 0) is right
	- (-1, 0) is left
	- (0, 1) is forward
	- (0, -1) is backward
	This method will normalize the direction vector to ensure consistent movement speed.
	If the direction is zero, it will stop the movement.
	"""
	_input_direction = direction.normalized()

func jump() -> void:
	"""Makes the parent CharacterBody3D jump if it is on the floor."""
	if _parent_body.is_on_floor():
		_parent_body.velocity.y = JUMP_VELOCITY
		# signal jump event if needed

func set_speed_multiplier(multiplier: float) -> void:
	"""Sets a multiplier on the base SPEED for dynamic speed adjustments."""
	_speed_multiplier = multiplier
