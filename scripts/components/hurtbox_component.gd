class_name HurtboxComponent
extends RigidBody3D

@export var health_component: HealthComponent

func _ready():
	if not health_component:
		var owner_node = get_owner()
		if owner_node and owner_node.has_node("HealthComponent"):
			health_component = owner_node.get_node("HealthComponent")
		else:
			push_error("HurtboxComponent requires a HealthComponent.")

func take_damage(damage_amount: float):
	Debug.log("HurtboxComponent received take_damage call with amount: %f" % damage_amount)
	if health_component:
		health_component.take_damage(damage_amount)
	else:
		push_error("HurtboxComponent is not associated with a HealthComponent.")
