extends CharacterBody3D
class_name SoccerCar

@export var acceleration: float = 30.0
@export var max_speed: float = 28.0
@export var reverse_speed: float = 10.0
@export var braking: float = 45.0
@export var coast_drag: float = 5.0
@export var steering_speed: float = 1.8
@export var jump_speed: float = 9.0
@export var gravity_strength: float = 22.0
@export var air_rotation_speed: float = 2.5
@export var boost_acceleration: float = 22.0
@export var boost_capacity: float = 100.0
@export var boost_use_rate: float = 30.0
@export var boost_recharge_rate: float = 8.0

var boost_amount: float
var jump_count: int = 0
var controls_enabled: bool = true
var is_local_player: bool = true

func _ready() -> void:
    add_to_group("cars")
    boost_amount = boost_capacity
    _build_visuals()

func _build_visuals() -> void:
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(1.8, 0.8, 3.0)
    collision.shape = shape
    collision.position.y = 0.55
    add_child(collision)

    var body_mesh := MeshInstance3D.new()
    var box := BoxMesh.new()
    box.size = Vector3(1.8, 0.8, 3.0)
    body_mesh.mesh = box
    body_mesh.position.y = 0.55
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.08, 0.55, 1.0) if is_local_player else Color(1.0, 0.28, 0.12)
    body_mesh.material_override = mat
    add_child(body_mesh)

func _physics_process(delta: float) -> void:
    if not controls_enabled:
        velocity = velocity.move_toward(Vector3.ZERO, braking * delta)
        if not is_on_floor():
            velocity.y -= gravity_strength * delta
        move_and_slide()
        return

    var grounded := is_on_floor()
    if grounded:
        jump_count = 0

    var throttle := Input.get_axis("reverse", "accelerate") if is_local_player else 0.0
    var steer := Input.get_axis("steer_left", "steer_right") if is_local_player else 0.0
    var horizontal := Vector3(velocity.x, 0.0, velocity.z)

    if grounded:
        rotate_y(-steer * steering_speed * delta)
        var forward := -global_basis.z
        var limit := max_speed if throttle >= 0.0 else reverse_speed
        if absf(throttle) > 0.01:
            horizontal = horizontal.move_toward(forward * throttle * limit, acceleration * delta)
        else:
            horizontal = horizontal.move_toward(Vector3.ZERO, coast_drag * delta)

        if is_local_player and Input.is_action_pressed("brake"):
            horizontal = horizontal.move_toward(Vector3.ZERO, braking * delta)

        velocity.x = horizontal.x
        velocity.z = horizontal.z
    else:
        velocity.y -= gravity_strength * delta
        if is_local_player:
            var pitch := Input.get_axis("air_pitch_down", "air_pitch_up")
            var roll := Input.get_axis("air_roll_right", "air_roll_left")
            rotate_object_local(Vector3.RIGHT, pitch * air_rotation_speed * delta)
            rotate_object_local(Vector3.FORWARD, roll * air_rotation_speed * delta)

    if is_local_player and Input.is_action_just_pressed("jump") and jump_count < 2:
        velocity.y = jump_speed
        jump_count += 1

    var boosting := is_local_player and Input.is_action_pressed("boost") and boost_amount > 0.0
    if boosting:
        velocity += -global_basis.z * boost_acceleration * delta
        boost_amount = maxf(0.0, boost_amount - boost_use_rate * delta)
    elif grounded:
        boost_amount = minf(boost_capacity, boost_amount + boost_recharge_rate * delta)

    horizontal = Vector3(velocity.x, 0.0, velocity.z)
    var speed_cap := max_speed + (boost_acceleration * 1.5 if boosting else 0.0)
    if horizontal.length() > speed_cap:
        horizontal = horizontal.normalized() * speed_cap
        velocity.x = horizontal.x
        velocity.z = horizontal.z

    move_and_slide()
