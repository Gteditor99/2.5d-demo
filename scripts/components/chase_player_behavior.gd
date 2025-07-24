class_name ChasePlayerBehavior
extends Node

@export var speed: float = 5.0
@export var acceleration: float = 8.0

var _parent_body: CharacterBody3D
var _player: CharacterBody3D

func _ready():
	_parent_body = get_parent() as CharacterBody3D
	if not _parent_body:
		push_error("ChasePlayerBehavior must be a child of a CharacterBody3D node.")
		set_process(false) # Disable processing if parent is not CharacterBody3D
		return
	
	_player = get_tree().get_first_node_in_group("Player")
	if not _player:
		push_error("Player node not found in group 'Player'.")
		set_process(false)
		return

func _process(delta: float):
	if not _player or not is_instance_valid(_player):
		return

	var direction_to_player = (_player.global_position - _parent_body.global_position).normalized()
	
	# Look at the player
	_parent_body.look_at(_player.global_position, Vector3.UP)

	# Calculate the movement direction based on the parent's orientation.
	var input_direction = Vector2(direction_to_player.x, direction_to_player.z).normalized()
	
	var velocity: Vector3 = _parent_body.velocity
	var current_target_speed = speed

	# Apply acceleration towards the target direction
	velocity.x = move_toward(velocity.x, input_direction.x * current_target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, input_direction.y * current_target_speed, acceleration * delta)
	
	_parent_body.velocity = velocity
	_parent_body.move_and_slide()
