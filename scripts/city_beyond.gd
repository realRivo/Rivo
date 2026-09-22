extends Node3D

const GRID_SIZE := 32
const CELL_SIZE := 4.0
const WORLD_SIZE := GRID_SIZE * CELL_SIZE

var camera: Camera3D
var city_root: Node3D
var buildings_root: Node3D
var roads_root: Node3D
var sim_time := 0.0
var population := 0

func _ready() -> void:
    _create_world()
    _create_camera()
    _create_lighting()
    _create_initial_roads()
    _create_initial_zones()
    _grow_initial_city()

func _process(delta: float) -> void:
    sim_time += delta
    if sim_time >= 3.0:
        sim_time = 0.0
        _simulate_growth()

func _create_world() -> void:
    city_root = Node3D.new()
    city_root.name = "City"
    add_child(city_root)

    roads_root = Node3D.new()
    roads_root.name = "Roads"
    city_root.add_child(roads_root)

    buildings_root = Node3D.new()
    buildings_root.name = "Buildings"
    city_root.add_child(buildings_root)

    var ground := MeshInstance3D.new()
    ground.name = "Ground"
    var mesh := PlaneMesh.new()
    mesh.size = Vector2(WORLD_SIZE, WORLD_SIZE)
    ground.mesh = mesh

    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.18, 0.24, 0.19)
    mat.roughness = 1.0
    ground.material_override = mat
    city_root.add_child(ground)

func _create_camera() -> void:
    camera = Camera3D.new()
    camera.name = "IsometricCamera"
    add_child(camera)
    camera.position = Vector3(55.0, 62.0, 55.0)
    camera.look_at(Vector3.ZERO, Vector3.UP)
    camera.fov = 42.0
    camera.current = true

func _create_lighting() -> void:
    var sun := DirectionalLight3D.new()
    sun.name = "Sun"
    sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
    sun.light_energy = 1.1
    sun.shadow_enabled = true
    add_child(sun)

    var world_env := WorldEnvironment.new()
    world_env.name = "WorldEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.055, 0.075, 0.10)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.62, 0.68, 0.76)
    env.ambient_light_energy = 0.65
    world_env.environment = env
    add_child(world_env)

func _create_initial_roads() -> void:
    for x in range(-3, 4):
        _make_road(Vector3(float(x) * CELL_SIZE, 0.06, 0.0), Vector3(3.0, 0.10, WORLD_SIZE * 0.72))
    for z in range(-3, 4):
        _make_road(Vector3(0.0, 0.07, float(z) * CELL_SIZE), Vector3(WORLD_SIZE * 0.72, 0.10, 3.0))

func _make_road(pos: Vector3, size: Vector3) -> void:
    var road := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    road.mesh = mesh
    road.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.10, 0.11, 0.12)
    mat.roughness = 0.92
    road.material_override = mat
    roads_root.add_child(road)

func _create_initial_zones() -> void:
    for x in range(-7, 8):
        for z in range(-7, 8):
            if abs(x) <= 3 or abs(z) <= 3:
                continue
            if (x + z) % 3 == 0:
                _make_zone(Vector3(x * CELL_SIZE, 0.03, z * CELL_SIZE), Color(0.20, 0.55, 0.30))
            elif (x + z) % 3 == 1:
                _make_zone(Vector3(x * CELL_SIZE, 0.035, z * CELL_SIZE), Color(0.22, 0.48, 0.70))
            else:
                _make_zone(Vector3(x * CELL_SIZE, 0.04, z * CELL_SIZE), Color(0.72, 0.48, 0.20))

func _make_zone(pos: Vector3, zone_color: Color) -> void:
    var zone := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = Vector3(CELL_SIZE - 0.18, 0.05, CELL_SIZE - 0.18)
    zone.mesh = mesh
    zone.position = pos
    var mat := StandardMaterial3D.new()
    mat.albedo_color = zone_color
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color.a = 0.34
    zone.material_override = mat
    city_root.add_child(zone)

func _grow_initial_city() -> void:
    var positions := [
        Vector3(-20, 0, -20), Vector3(-12, 0, -20), Vector3(20, 0, -20),
        Vector3(-20, 0, -12), Vector3(20, 0, -12),
        Vector3(-20, 0, 12), Vector3(20, 0, 12),
        Vector3(-20, 0, 20), Vector3(-12, 0, 20), Vector3(20, 0, 20)
    ]
    for p in positions:
        _spawn_building(p, 1)

func _simulate_growth() -> void:
    if buildings_root.get_child_count() >= 34:
        return
    var n := buildings_root.get_child_count()
    var gx := (n % 7) - 3
    var gz := int(n / 7) - 3
    var pos := Vector3(gx * CELL_SIZE * 1.35, 0.0, gz * CELL_SIZE * 1.35)
    if abs(gx) <= 1 and abs(gz) <= 1:
        pos.x += 14.0
    _spawn_building(pos, 1 + int(n / 12))

func _spawn_building(pos: Vector3, level: int) -> void:
    var b := MeshInstance3D.new()
    b.name = "Building_%d" % buildings_root.get_child_count()
    var mesh := BoxMesh.new()
    var height := 2.5 + float(level) * 1.8
    mesh.size = Vector3(2.7, height, 2.7)
    b.mesh = mesh
    b.position = Vector3(pos.x, height * 0.5, pos.z)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.42 + 0.04 * (level % 3), 0.46 + 0.03 * (level % 4), 0.52 + 0.02 * (level % 5))
    mat.roughness = 0.72
    b.material_override = mat
    buildings_root.add_child(b)
    population += 4 * level
