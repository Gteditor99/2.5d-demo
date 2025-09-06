@tool
class_name WeaponData
extends ItemData

const RecoilData = preload("res://scripts/resources/RecoilData/RecoilData.gd")


## WEAPON STATS
@export_group("Weapon Stats")
@export var damage: int = 10
@export var rounds_per_minute: int = 600
@export var range: float = 1000.0

## MAGAZINE
@export_group("Magazine")
@export var magazine_size: int = 30
@export var reload_time: float = 2.5

## FIRE MODES
@export_group("Fire Modes")
@export var available_fire_modes: Array[String] = ["semi-auto", "full-auto"]
@export var default_fire_mode: String = "full-auto"
@export var burst_count: int = 3 # Only used for burst fire mode

## RECOIL & SPREAD
@export_group("Recoil & Spread")
@export var spread_angle: float = 1.0 # In degrees
@export var recoil_data: RecoilData


## PROJECTILE
@export_group("Projectile")
@export var projectile_scene: PackedScene

## VIEW MODEL
@export_group("View Model")
@export var weapon_scene: PackedScene

@export_group("Idle State")
@export var idle_view_offset: Vector3 = Vector3.ZERO
@export var idle_view_rotation: Vector3 = Vector3.ZERO
@export var idle_fov: float = 75.0
@export var idle_transition_speed: float = 10.0

@export_group("Sprinting State")
@export var sprint_view_offset: Vector3 = Vector3(0, -0.1, 0.1)
@export var sprint_view_rotation: Vector3 = Vector3.ZERO
@export var sprint_fov: float = 85.0
@export var sprint_transition_speed: float = 8.0

@export_group("Aiming State")
@export var ads_view_offset: Vector3 = Vector3.ZERO
@export var ads_view_rotation: Vector3 = Vector3.ZERO
@export var ads_fov: float = 50.0
@export var ads_transition_speed: float = 15.0

@export_group("Sway")
@export var sway_speed: float = 5.0
@export var sway_intensity: float = 0.05
@export var max_sway_x: float = 2.0
@export var max_sway_y: float = 2.0
@export var ads_sway_multiplier: float = 0.5
