class_name WeaponSystemComponent
extends Node

const ProjectilePool = preload("res://scripts/components/projectile_pool.gd")
const RecoilDebugMenu = preload("res://scenes/ui/recoil_debug/recoil_debug_menu.tscn")

signal ammo_updated(current_ammo, reserve_ammo)
signal weapon_fired
signal weapon_reloaded
signal weapon_reload_started

@export var weapon_data: WeaponData
@export var view_model_component: ViewModelComponent

var current_ammo: int
var reserve_ammo: int = 0 # You can expand this later for a full inventory system
var current_fire_mode: String
var is_aiming: bool = false
@onready var fire_rate_timer: Timer
@onready var reload_timer: Timer
var projectile_pool: ProjectilePool
var recoil_debug_menu_instance: PanelContainer

func _ready():
	fire_rate_timer = Timer.new()
	reload_timer = Timer.new()
	if not weapon_data:
		push_error("WeaponSystemComponent requires a WeaponData resource.")
		set_process(false)
		set_physics_process(false)
		return

	current_ammo = weapon_data.magazine_size
	if view_model_component:
		view_model_component.set_weapon_system_component(self)
	current_fire_mode = weapon_data.default_fire_mode

	# Setup timers
	fire_rate_timer.wait_time = 60.0 / weapon_data.rounds_per_minute
	fire_rate_timer.one_shot = true
	add_child(fire_rate_timer)

	reload_timer.wait_time = weapon_data.reload_time
	reload_timer.one_shot = true
	reload_timer.timeout.connect(_on_reload_finished)
	add_child(reload_timer)

	emit_signal("ammo_updated", current_ammo, reserve_ammo)

	if weapon_data.projectile_scene:
		projectile_pool = ProjectilePool.new(weapon_data.projectile_scene)
		add_child(projectile_pool)


func handle_input():
	match current_fire_mode:
		"semi-auto":
			if Input.is_action_just_pressed("shoot"):
				attempt_fire()
		"full-auto":
			if Input.is_action_pressed("shoot"):
				attempt_fire()
	if Input.is_action_just_pressed("reload"):
		attempt_reload()
	
	if Input.is_action_just_pressed("switch_fire_mode"):
		switch_fire_mode()
		
	if Input.is_action_just_pressed("aim"):
		is_aiming = true
	elif Input.is_action_just_released("aim"):
		is_aiming = false
		
	
func attempt_fire() -> bool:
	if current_ammo > 0:
		if fire_rate_timer.is_stopped():
			_fire()
			return true
	elif reload_timer.is_stopped():
		attempt_reload()
	return false

func attempt_reload():
	if current_ammo < weapon_data.magazine_size and reload_timer.is_stopped():
		Debug.log("Reloading...")
		emit_signal("weapon_reload_started")
		reload_timer.start()

func switch_fire_mode():
	var current_index = weapon_data.available_fire_modes.find(current_fire_mode)
	if current_index != -1:
		var next_index = (current_index + 1) % weapon_data.available_fire_modes.size()
		current_fire_mode = weapon_data.available_fire_modes[next_index]
		Debug.log("Switched to %s" % current_fire_mode)

func _fire():
	Debug.log("Firing weapon.")
	fire_rate_timer.start()
	current_ammo -= 1
	emit_signal("weapon_fired")
	emit_signal("ammo_updated", current_ammo, reserve_ammo)

	if view_model_component and weapon_data.recoil_data:
		var recoil_data = weapon_data.recoil_data
		view_model_component.apply_recoil()


	# Instantiate and fire projectile
	if weapon_data.projectile_scene:
		var projectile_instance = projectile_pool.get_projectile()
		var projectile_component = projectile_instance.get_node("ProjectileComponent") as ProjectileComponent
		
		if projectile_component:
			var owner_entity = get_owner() as Node3D
			if owner_entity and owner_entity.has_method("get_barrel_node"):
				var barrel_node = owner_entity.get_barrel_node()
				if barrel_node:
					projectile_instance.global_transform = barrel_node.global_transform
					projectile_component.direction = - barrel_node.global_transform.basis.z
				else:
					# Fallback to owner's transform if barrel_node is not found
					projectile_instance.global_transform = owner_entity.global_transform
					projectile_component.direction = - owner_entity.global_transform.basis.z

				# Add collision exception
				if projectile_instance is RigidBody3D:
					projectile_instance.add_collision_exception_with(owner_entity)
			
			projectile_component.damage = weapon_data.damage
			projectile_component.fire()
			# You can add more properties from WeaponData to the projectile here


func _on_reload_finished():
	var needed_ammo = weapon_data.magazine_size - current_ammo
	# For now, we'll assume infinite reserve ammo for simplicity
	# In a full system, you'd check reserve_ammo here
	current_ammo += needed_ammo
	emit_signal("weapon_reloaded")
	emit_signal("ammo_updated", current_ammo, reserve_ammo)
	Debug.log("Reload finished.")
