extends Resource
class_name RecoilData

## Defines the recoil behavior for a weapon.

@export_group("Recoil")
## The amount of randomness applied to the recoil pattern.
@export var randomness: float = 0.1
## The speed at which the weapon recovers from recoil.
@export var recovery_speed: float = 10.0

@export_group("Spring")
## The stiffness of the positional spring.
@export var positional_stiffness: float = 100.0
## The damping of the positional spring.
@export var positional_damping: float = 10.0
## The stiffness of the rotational spring.
@export var rotational_stiffness: float = 100.0
## The damping of the rotational spring.
@export var rotational_damping: float = 10.0

@export_group("Kick")
## The upward kick force applied to the weapon's position.
@export var positional_kick_up: float = 0.0
## The backward kick force applied to the weapon's position.
@export var positional_kick_back: float = 0.0
## The horizontal kick force applied to the weapon's position (left/right sway).
@export var positional_kick_horizontal: float = 0.0
## The upward kick force applied to the weapon's rotation.
@export var rotational_kick_up: float = 0.0
## The backward kick force applied to the weapon's rotation.
@export var rotational_kick_back: float = 0.0
## The horizontal kick force applied to the weapon's rotation (left/right sway).
@export var rotational_kick_horizontal: float = 0.0

@export_group("ADS (Aim Down Sights)")
## Multiplier for positional recoil when aiming down sights (0.0 = no recoil, 1.0 = full recoil).
@export_range(0.0, 1.0) var ads_positional_multiplier: float = 0.5
## Multiplier for rotational recoil when aiming down sights (0.0 = no recoil, 1.0 = full recoil).
@export_range(0.0, 1.0) var ads_rotational_multiplier: float = 0.4

@export_group("Positional Recoil Curves")
@export var positional_recoil_curve_x: Curve
@export var positional_recoil_curve_y: Curve
@export var positional_recoil_curve_z: Curve

@export_group("Rotational Recoil Curves")
@export var rotational_recoil_curve_x: Curve
@export var rotational_recoil_curve_y: Curve
@export var rotational_recoil_curve_z: Curve