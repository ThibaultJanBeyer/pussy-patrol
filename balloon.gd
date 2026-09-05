extends RigidBody2D

@export var spin_speed := 1.2 ## Radians per second while walking.

var exploding := false
var _spin_dir := 1.0

func _ready() -> void:
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.play("walk")
	_spin_dir = 1.0 if randf() > 0.5 else -1.0
	await get_tree().physics_frame
	$WalkCollision.disabled = false

func _process(delta: float) -> void:
	if exploding:
		return
	$AnimatedSprite2D.rotation += spin_speed * _spin_dir * delta

func explode() -> void:
	if exploding:
		return
	exploding = true
	linear_velocity = Vector2.ZERO
	freeze = true
	$WalkCollision.set_deferred("disabled", true)
	$ExplodeCollision.set_deferred("disabled", true)
	$AnimatedSprite2D.play("explode")

func _on_animation_finished() -> void:
	if exploding:
		queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
