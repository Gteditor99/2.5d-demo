class_name HurtboxComponent
extends Area3D

const HealthComponent = preload("res://scripts/components/health_component.gd")
@export var health_component: HealthComponent

func _ready():
	if not health_component:
		push_error("HurtboxComponent requires a HealthComponent.")

func take_damage(damage: int):
	if health_component:
		health_component.take_damage(damage)
