extends RigidBody2D

enum Kind { DEFAULT, BISCUIT, STICK, FISH, HEART, PACK }

const WEIGHTS := {
	Kind.DEFAULT: 60.0,
	Kind.BISCUIT: 20.0,
	Kind.STICK: 10.0,
	Kind.FISH: 5.0,
	Kind.HEART: 2.5,
	Kind.PACK: 2.5,
}
const ANIM_NAMES := {
	Kind.DEFAULT: "default",
	Kind.BISCUIT: "biscuit",
	Kind.STICK: "stick",
	Kind.FISH: "fish",
	Kind.HEART: "heart",
	Kind.PACK: "pack",
}
const POINTS := {
	Kind.DEFAULT: 1,
	Kind.BISCUIT: 2,
	Kind.STICK: 3,
	Kind.FISH: 5,
}
const PACK_INVULN_SECONDS := 5.0

const SIZE_MULTIPLIERS := {
	Kind.DEFAULT: 1.0,
	Kind.BISCUIT: 1.4,
	Kind.STICK: 1.5,
	Kind.FISH: 1.6,
	Kind.HEART: 2,
	Kind.PACK: 2.5,
}

const POINT_COLOR := Color(1.0, 0.84, 0.0) # gold
const LIFE_COLOR := Color(0.9, 0.15, 0.15) # red

const LIFETIME_SECONDS := 10.0
const BLINK_WINDOW_SECONDS := 1.5 # start blinking this long before despawning
const BLINK_HZ := 3.0
const BLINK_MIN_ALPHA := 0.5 # dips to 50% transparent at the trough of each pulse

var kind: Kind

func _ready() -> void:
	kind = _roll_kind()
	$AnimatedSprite2D.play(ANIM_NAMES[kind])
	$AnimatedSprite2D.scale *= SIZE_MULTIPLIERS[kind]
	$LifeTimer.wait_time = LIFETIME_SECONDS
	$LifeTimer.start()

func _process(_delta: float) -> void:
	var t: float = $LifeTimer.time_left
	if t > 0.0 and t <= BLINK_WINDOW_SECONDS:
		var phase := sin(t * TAU * BLINK_HZ) * 0.5 + 0.5
		$AnimatedSprite2D.modulate.a = lerpf(BLINK_MIN_ALPHA, 1.0, phase)

func _roll_kind() -> Kind:
	var r := randf() * 100.0
	for k in WEIGHTS:
		r -= WEIGHTS[k]
		if r <= 0.0:
			return k
	return Kind.DEFAULT

func collect(player: Node) -> void:
	match kind:
		Kind.HEART:
			get_parent().add_life()
			Fx.floating_text(global_position, "+1", LIFE_COLOR)
		Kind.PACK:
			player.activate_pack(PACK_INVULN_SECONDS)
			Fx.floating_text(global_position, "%ds" % int(PACK_INVULN_SECONDS), LIFE_COLOR)
		_:
			var points: int = POINTS[kind]
			get_parent().add_points(points)
			Fx.floating_text(global_position, "+%d" % points, POINT_COLOR)
	queue_free()

func _on_life_timer_timeout() -> void:
	queue_free()

func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
