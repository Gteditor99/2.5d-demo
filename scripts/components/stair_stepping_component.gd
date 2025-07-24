class_name StairSteppingComponent
extends Node

## Component for advanced, physics-based stair stepping for CharacterBody3D.
## Handles step up and step down.

#region Signals
signal step_processed(step_result)
#endregion

#region Exports
@export_group("Stair Stepping Configuration")
@export var MAX_STEP_UP: float = 0.6
@export var MAX_STEP_DOWN: float = -0.6
@export var floor_max_angle: float = 40.0
#endregion

#region Private Variables
var _parent_body: CharacterBody3D
var _vertical: Vector3 = Vector3.UP
#endregion

#region Inner Classes
class StepResult:
	var diff_position: Vector3 = Vector3.ZERO
	var normal: Vector3 = Vector3.ZERO
	var is_step_up: bool = false
#endregion


func _ready() -> void:
	_parent_body = get_parent() as CharacterBody3D
	if not _parent_body:
		push_error("StairSteppingComponent must be a child of a CharacterBody3D.")
		set_physics_process(false)
		return
	floor_max_angle = deg_to_rad(floor_max_angle)

#=============================================================================
#region Public API
#=============================================================================
func check_for_stairs(wish_dir: Vector3, was_grounded: bool) -> StepResult:
	var step_result := StepResult.new()
	
	stair_step_up(wish_dir, step_result)
	stair_step_down(wish_dir, was_grounded, step_result)
	
	step_processed.emit(step_result)
	return step_result
#endregion

#=============================================================================
#region Private Methods
#================================com=============================================
# Function: Handle walking down stairs
func stair_step_down(wish_dir: Vector3, was_grounded: bool, step_result: StepResult):
	# print("stair_step_down called. wish_dir: ", wish_dir, " was_grounded: ", was_grounded, " is_on_floor: ", _parent_body.is_on_floor())
	if wish_dir == Vector3.ZERO or not was_grounded or _parent_body.is_on_floor():
		return

	var body_test_params = PhysicsTestMotionParameters3D.new()
	var body_test_result = PhysicsTestMotionResult3D.new()

	var test_transform = _parent_body.global_transform
	var forward_cast_dist = _parent_body.velocity * 0.2
	forward_cast_dist.y = 0
	
	# 1. Cast forward to find a wall
	body_test_params.from = test_transform
	body_test_params.motion = forward_cast_dist
	PhysicsServer3D.body_test_motion(_parent_body.get_rid(), body_test_params, body_test_result)
	test_transform = test_transform.translated(body_test_result.get_travel())
	print("Step down forward cast travel: ", body_test_result.get_travel())

	# 2. Cast downward from the forward position
	body_test_params.from = test_transform
	body_test_params.motion = Vector3(0, MAX_STEP_DOWN, 0)
	if PhysicsServer3D.body_test_motion(_parent_body.get_rid(), body_test_params, body_test_result):
		var step_down_dist = body_test_result.get_travel()
		_parent_body.global_position += step_down_dist
		step_result.diff_position = step_down_dist
		print("Step down successful. Distance: ", step_down_dist)
	else:
		print("Step down failed. No ground detected.")


# Function: Handle walking up stairs
func stair_step_up(wish_dir: Vector3, step_result: StepResult):
	if wish_dir == Vector3.ZERO:
		return

	# 0. Initialize testing variables
	var body_test_params = PhysicsTestMotionParameters3D.new()
	var body_test_result = PhysicsTestMotionResult3D.new()

	var test_transform = _parent_body.global_transform ## Storing current global_transform for testing
	var distance = wish_dir * 0.1 ## Distance forward we want to check
	body_test_params.from = _parent_body.global_transform ## Self as origin point
	body_test_params.motion = distance ## Go forward by current distance

	# Pre-check: Are we colliding?
	if !PhysicsServer3D.body_test_motion(_parent_body.get_rid(), body_test_params, body_test_result):
		## If we don't collide, return
		return

	# 1. Move test_transform to collision location
	var remainder = body_test_result.get_remainder() ## Get remainder from collision
	test_transform = test_transform.translated(body_test_result.get_travel()) ## Move test_transform by distance traveled before collision

	# 2. Move test_transform up to ceiling (if any)
	var step_up = MAX_STEP_UP * _vertical
	body_test_params.from = test_transform
	body_test_params.motion = step_up
	PhysicsServer3D.body_test_motion(_parent_body.get_rid(), body_test_params, body_test_result)
	test_transform = test_transform.translated(body_test_result.get_travel())

	# 3. Move test_transform forward by remaining distance
	body_test_params.from = test_transform
	body_test_params.motion = remainder
	PhysicsServer3D.body_test_motion(_parent_body.get_rid(), body_test_params, body_test_result)
	test_transform = test_transform.translated(body_test_result.get_travel())

	# 3.5 Project remaining along wall normal (if any)
	## So you can walk into wall and up a step
	if body_test_result.get_collision_count() != 0:
		remainder = body_test_result.get_remainder()

		### Uh, there may be a better way to calculate this in Godot.
		var wall_normal = body_test_result.get_collision_normal()
		var projected_vector = remainder.slide(wall_normal).normalized() * remainder.length()


		body_test_params.from = test_transform
		body_test_params.motion = projected_vector
		PhysicsServer3D.body_test_motion(_parent_body.get_rid(), body_test_params, body_test_result)
		test_transform = test_transform.translated(body_test_result.get_travel())

	# 4. Move test_transform down onto step
	body_test_params.from = test_transform
	body_test_params.motion = MAX_STEP_UP * -_vertical

	# Return if no collision
	if !PhysicsServer3D.body_test_motion(_parent_body.get_rid(), body_test_params, body_test_result):
		return

	test_transform = test_transform.translated(body_test_result.get_travel())

	# 5. Check floor normal for un-walkable slope
	var surface_normal = body_test_result.get_collision_normal()
	if (snappedf(surface_normal.angle_to(_vertical), 0.001) > floor_max_angle):
		return

	# 6. Move player up
	var global_pos = _parent_body.global_position
	var step_up_dist = test_transform.origin - global_pos
	
	step_result.diff_position = step_up_dist
	step_result.is_step_up = true
	_parent_body.global_position += step_up_dist
#endregion
