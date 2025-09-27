class_name ChaseAttackAIBehavior
extends EnemyAIBehavior

@export var detection_range: float = 12.0
@export var disengage_range: float = 18.0
@export var attack_range: float = 2.5
@export var attack_cooldown: float = 1.25

var _cooldown_timer: float = 0.0

func setup(controller: EnemyAIController) -> void:
        _cooldown_timer = 0.0
        controller.set_state(EnemyAIController.State.IDLE)

func physics_update(controller: EnemyAIController, delta: float) -> void:
        if controller.state == EnemyAIController.State.DEAD:
                return

        if not controller.has_player():
                controller.stop_movement()
                controller.ensure_state(EnemyAIController.State.IDLE)
                return

        var distance_to_player := controller.distance_to_player()

        match controller.state:
                EnemyAIController.State.IDLE:
                        if distance_to_player <= detection_range:
                                controller.set_state(EnemyAIController.State.CHASE)
                EnemyAIController.State.CHASE:
                        if distance_to_player > disengage_range:
                                controller.set_state(EnemyAIController.State.IDLE)
                                controller.stop_movement()
                                return

                        controller.face_player()
                        controller.move_towards_player()

                        if distance_to_player <= attack_range:
                                controller.set_state(EnemyAIController.State.ATTACK)
                                _cooldown_timer = 0.0
                EnemyAIController.State.ATTACK:
                        controller.stop_movement()
                        controller.face_player()

                        _cooldown_timer -= delta
                        if _cooldown_timer <= 0.0:
                                controller.request_attack()
                                _cooldown_timer = attack_cooldown

                        if distance_to_player > attack_range * 1.3:
                                controller.set_state(EnemyAIController.State.CHASE)
                EnemyAIController.State.DEAD:
                        controller.stop_movement()

func on_state_changed(controller: EnemyAIController, previous_state: EnemyAIController.State, new_state: EnemyAIController.State) -> void:
        if new_state == EnemyAIController.State.IDLE:
                controller.stop_movement()
        elif new_state == EnemyAIController.State.CHASE and previous_state == EnemyAIController.State.ATTACK:
                _cooldown_timer = 0.0
