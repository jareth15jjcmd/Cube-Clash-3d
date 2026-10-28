extends RigidBody3D
class_name SoccerBall

@export var hit_strength: float = 5.0
@export var upward_lift: float = 1.5
@export var minimum_hit_speed: float = 2.0
@export var max_ball_speed: float = 42.0

func _ready() -> void:
    add_to_group("match_ball")
    contact_monitor = true
    max_contacts_reported = 8
    body_entered.connect(_on_body_entered)
    _build_visuals()

func _build_visuals() -> void:
    var collision := CollisionShape3D.new()
    var sphere := SphereShape3D.new()
    sphere.radius = 1.5
    collision.shape = sphere
    add_child(collision)

    var mesh_instance := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius = 1.5
    mesh.height = 3.0
    mesh_instance.mesh = mesh
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.72, 0.12)
    material.roughness = 0.45
    mesh_instance.material_override = material
    add_child(mesh_instance)

    mass = 100.0
    linear_damp = 0.08
    angular_damp = 0.12
    var physics_material := PhysicsMaterial.new()
    physics_material.bounce = 0.75
    physics_material.friction = 0.35
    physics_material_override = physics_material

func _on_body_entered(body: Node) -> void:
    if not body is SoccerCar:
        return
    var car := body as SoccerCar
    var car_speed := Vector3(car.velocity.x, car.velocity.y, car.velocity.z).length()
    if car_speed < minimum_hit_speed:
        return
    var away := (global_position - car.global_position).normalized()
    var forward := -car.global_basis.z
    var direction := (forward * 0.75 + away * 0.25).normalized()
    apply_central_impulse(direction * car_speed * hit_strength + Vector3.UP * upward_lift)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    var speed := state.linear_velocity.length()
    if speed > max_ball_speed:
        state.linear_velocity = state.linear_velocity.normalized() * max_ball_speed
