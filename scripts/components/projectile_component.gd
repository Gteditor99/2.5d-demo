class_name ProjectileComponent
extends Node

signal returned_to_pool

@export var speed: float = 100.0
@export var damage: int = 10
@export var lifetime: float = 5.0 # in seconds

var direction: Vector3 = Vector3.FORWARD
var lifetime_timer: Timer

func _ready():
	var parent_body = get_parent() as RigidBody3D
	if not parent_body:
		push_error("ProjectileComponent must be a child of a RigidBody3D.")
		return

	# Connect to the body_entered signal for collision detection
	parent_body.body_entered.connect(_on_body_entered)

	lifetime_timer = Timer.new()
	lifetime_timer.wait_time = lifetime
	lifetime_timer.one_shot = true
	lifetime_timer.timeout.connect(_on_lifetime_timer_timeout)
	add_child(lifetime_timer)

func fire():
	var parent_body = get_parent() as RigidBody3D
	parent_body.linear_velocity = direction * speed
	lifetime_timer.start()

func get_damage() -> int:
	return damage

func _on_body_entered(body: Node):
	Debug.log("Projectile collided with: %s" % body.name)

	if body.has_method("take_damage"):
		Debug.log("Collision with a damageable object detected. Applying damage.")
		body.call("take_damage", damage)
	else:
		Debug.log("Collision was not with a damageable object.")

	# Return the projectile to the pool
	emit_signal("returned_to_pool", get_parent())

func _on_lifetime_timer_timeout():
	Debug.log("Projectile lifetime expired.")
	# Return the projectile to the pool
	emit_signal("returned_to_pool", get_parent())
