class_name HealthComponent
extends Node

signal hurt
signal no_health

@export var max_health: int = 100

var health: int

func _ready():
	health = max_health

func take_damage(damage: int):
	if health <= 0:
		return

	print("HealthComponent: Taking %d damage. Current health: %d" % [damage, health])
	health -= damage
	print("HealthComponent: New health: %d" % health)
	emit_signal("hurt")
	if health <= 0:
		health = 0
		emit_signal("no_health")
