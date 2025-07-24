extends Node3D

@export var SPEED = 10.0
@export var damage: int = 25 # How much damage the bullet deals
@export var xyz_offset = Vector3(0, 0, 0) # Negative is forward

@onready var raycast = $RayCast3D

func _ready():
	position += transform.basis * xyz_offset

func _process(delta):
	var travel_distance = SPEED * delta
	raycast.target_position = Vector3(0, 0, -travel_distance)
	raycast.force_raycast_update()

	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Move bullet to the point of impact
		global_position = raycast.get_collision_point()

		if collider and collider.has_method("take_damage"):
			# The object we hit has a take_damage method, so call it.
			collider.call("take_damage", damage)
		
		# Destroy the bullet on any impact
		#queue_free()
		return

	# If no collision, move the bullet forward
	position += transform.basis * Vector3(0, 0, -SPEED) * delta
