extends Node3D

@export var SPEED = 10.0
@export var xyz_offset = Vector3(0, 0, 0) # Negative is forward

@onready var mesh = $MeshInstance3D
@onready var raycast = $RayCast3D

func _ready():
	print("Bullet ready @", position)
	position += transform.basis * xyz_offset

func _process(delta):
	var travel_distance = SPEED * delta
	$RayCast3D.target_position = Vector3(0, 0, -travel_distance)
	$RayCast3D.force_raycast_update()

	if $RayCast3D.is_colliding():
		var collider = $RayCast3D.get_collider()
		print("Bullet collided with: ", collider.name, " of type ", collider.get_class())
		if collider and collider.has_method("kill"):
			print("Collider has kill method. Calling kill().")
			# Move bullet to the point of impact
			position = $RayCast3D.get_collision_point()
			collider.kill()
			queue_free() # Destroy bullet on impact
			return # Stop further processing for this frame
		else:
			print("Collider does not have kill method or is null.")
			
	# If no collision, move the bullet forward
	position += transform.basis * Vector3(0, 0, -SPEED) * delta
	pass
