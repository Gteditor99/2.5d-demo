class_name HealthComponent
extends Node

signal health_changed(current_health, max_health)
signal died

@export var max_health: float = 100.0
var current_health: float

func _ready():
	current_health = max_health

func take_damage(damage_amount: float):
	current_health = max(0, current_health - damage_amount)
	emit_signal("health_changed", current_health, max_health)
	Debug.log(get_owner().name + " took " + str(damage_amount) + " damage. Health is now " + str(current_health))


	if current_health == 0:
		emit_signal("died")
		Debug.log(get_owner().name + " has died.")
