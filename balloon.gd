extends RigidBody2D

@export var spin_speed := 1.2 ## Radians per second while walking.
@export_range(0.0, 1.0) var explode_chance := 0.25 ## Odds THIS balloon explodes on a mid-air hit, rolled independently per side — a collision can pop just one, both, or neither.

var exploding := false
var _spin_dir := 1.0

func _ready() -> void:
	$AnimatedSprite2D.animation_finished.connect(_on_animation_finished)
	$AnimatedSprite2D.play("walk")
	_spin_dir = 1.0 if randf() > 0.5 else -1.0
	# Physics-driven spin, not a per-frame rotation increment: this way the
	# body's own rotation stays the single source of truth that the sprite
	# AND the collision shapes (both children of it) always share, and a
	# bounce naturally adds to it instead of fighting a separately-scripted one.
	angular_velocity = spin_speed * _spin_dir
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_balloon_contact)
	await get_tree().physics_frame
	$WalkCollision.disabled = false

func explode() -> void:
	if exploding:
		return
	exploding = true
	# Keep carrying its current velocity instead of stopping dead — the burst
	# reads better as debris still flying than as hitting an invisible wall.
	$WalkCollision.set_deferred("disabled", true)
	$ExplodeCollision.set_deferred("disabled", true)
	$AnimatedSprite2D.play("explode")

func _on_animation_finished() -> void:
	if exploding:
		queue_free()

func _on_balloon_contact(body: Node) -> void:
	if exploding or not body.is_in_group("mobs") or not body.has_method("explode"):
		return
	# Each side rolls for itself — the other balloon runs this same check
	# independently for the same hit, so the two outcomes aren't linked.
	if randf() < explode_chance:
		explode()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
