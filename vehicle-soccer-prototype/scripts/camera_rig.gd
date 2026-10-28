extends Camera3D
class_name SoccerCamera

@export var target_car: Node3D
@export var target_ball: Node3D
@export var follow_distance: float = 8.0
@export var follow_height: float = 3.0
@export var follow_smoothing: float = 7.0
@export var aim_smoothing: float = 5.0

var ball_cam_enabled := false

func _process(delta: float) -> void:
    if target_car == null:
        return
    if Input.is_action_just_pressed("toggle_ball_cam"):
        ball_cam_enabled = not ball_cam_enabled

    var car_forward := -target_car.global_basis.z
    var desired_position := target_car.global_position - car_forward * follow_distance + Vector3.UP * follow_height
    global_position = global_position.lerp(desired_position, 1.0 - exp(-follow_smoothing * delta))

    var look_target := target_car.global_position + Vector3.UP
    if ball_cam_enabled and target_ball != null:
        look_target = target_ball.global_position

    var direction := look_target - global_position
    if direction.length_squared() > 0.001:
        var desired_basis := Basis.looking_at(direction.normalized(), Vector3.UP)
        global_basis = global_basis.slerp(desired_basis, 1.0 - exp(-aim_smoothing * delta))
