extends Node3D

# CityBeyond - Feature Set 1: Core City Engine
# Functional foundation: isometric camera, grid map, road network,
# zone painting, automatic R/C/I growth, simulation speed and HUD.

const GRID_SIZE := 48
const CELL_SIZE := 2.5
const WORLD_SIZE := GRID_SIZE * CELL_SIZE
const ROAD_WIDTH := 1.25
const MAX_BUILDINGS := 420

enum ZoneType { NONE, RESIDENTIAL, COMMERCIAL, INDUSTRIAL }

var camera: Camera3D
var city_root: Node3D
var roads_root: Node3D
var zones_root: Node3D
var buildings_root: Node3D
var ui: CanvasLayer
var info_label: Label
var demand_label: Label
var mode_label: Label
var speed_button: Button

var day_timer := 0.0
var day := 1
var population := 0
var jobs := 0
var money := 50000
var happiness := 62.0
var sim_speed := 1.0
var selected_zone := ZoneType.RESIDENTIAL
var paused := false

var demand := {
  ZoneType.RESIDENTIAL: 0.72,
  ZoneType.COMMERCIAL: 0.48,
  ZoneType.INDUSTRIAL: 0.60
}

var zone_map: Dictionary = {}
var building_map: Dictionary = {}
var road_cells: Dictionary = {}
var zone_visuals: Dictionary = {}

var camera_target := Vector3.ZERO
var camera_distance := 72.0
var camera_yaw := 45.0
var camera_pitch := 55.0
var dragging := false
var last_pointer := Vector2.ZERO

func _ready() -> void:
  randomize()
  _create_world()
  _create_camera()
  _create_lighting()
  _create_roads()
  _create_zones()
  _create_ui()
  _spawn_starter_city()
  _update_ui()

func _process(delta: float) -> void:
  if paused:
    return
  day_timer += delta * sim_speed
  if day_timer >= 1.0:
    day_timer -= 1.0
    _simulate_one_day()

func _unhandled_input(event: InputEvent) -> void:
  if event is InputEventScreenTouch:
    if event.pressed:
      dragging = true
      last_pointer = event.position
    else:
      if dragging and event.position.distance_to(last_pointer) < 18.0:
        _paint_zone_from_screen(event.position)
      dragging = false
  elif event is InputEventScreenDrag and dragging:
    var d := event.relative
    camera_yaw -= d.x * 0.35
    camera_pitch = clamp(camera_pitch - d.y * 0.18, 30.0, 78.0)
    _update_camera()
  elif event is InputEventMouseButton:
    if event.button_index == MOUSE_BUTTON_LEFT:
      if event.pressed:
        dragging = true
        last_pointer = event.position
      elif dragging:
        if event.position.distance_to(last_pointer) < 8.0:
          _paint_zone_from_screen(event.position)
        dragging = false
    elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
      camera_distance = max(28.0, camera_distance - 6.0)
      _update_camera()
    elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
      camera_distance = min(150.0, camera_distance + 6.0)
      _update_camera()
  elif event is InputEventMouseMotion and dragging:
    var d := event.relative
    camera_yaw -= d.x * 0.35
    camera_pitch = clamp(camera_pitch - d.y * 0.18, 30.0, 78.0)
    _update_camera()

func _create_world() -> void:
  city_root = Node3D.new()
  city_root.name = "City"
  add_child(city_root)

  roads_root = Node3D.new()
  roads_root.name = "Roads"
  city_root.add_child(roads_root)

  zones_root = Node3D.new()
  zones_root.name = "Zones"
  city_root.add_child(zones_root)

  buildings_root = Node3D.new()
  buildings_root.name = "Buildings"
  city_root.add_child(buildings_root)

  var ground := MeshInstance3D.new()
  ground.name = "Ground"
  var mesh := PlaneMesh.new()
  mesh.size = Vector2(WORLD_SIZE, WORLD_SIZE)
  ground.mesh = mesh
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.12, 0.17, 0.14)
  mat.roughness = 1.0
  ground.material_override = mat
  city_root.add_child(ground)

  # Subtle grid lines make the buildable cells readable.
  for i in range(-GRID_SIZE / 2, GRID_SIZE / 2 + 1):
    _make_grid_line(Vector3(i * CELL_SIZE, 0.012, 0), Vector3(0.018, 0.018, WORLD_SIZE))
    _make_grid_line(Vector3(0, 0.013, i * CELL_SIZE), Vector3(WORLD_SIZE, 0.018, 0.018))

func _make_grid_line(pos: Vector3, size: Vector3) -> void:
  var line := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = size
  line.mesh = mesh
  line.position = pos
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.28, 0.34, 0.30)
  mat.roughness = 1.0
  line.material_override = mat
  city_root.add_child(line)

func _create_camera() -> void:
  camera = Camera3D.new()
  camera.name = "IsometricCamera"
  camera.fov = 48.0
  camera.current = true
  add_child(camera)
  _update_camera()

func _update_camera() -> void:
  if camera == null:
    return
  var yaw := deg_to_rad(camera_yaw)
  var pitch := deg_to_rad(camera_pitch)
  var horizontal := cos(pitch) * camera_distance
  camera.position = camera_target + Vector3(
    cos(yaw) * horizontal,
    sin(pitch) * camera_distance,
    sin(yaw) * horizontal
  )
  camera.look_at(camera_target, Vector3.UP)

func _create_lighting() -> void:
  var sun := DirectionalLight3D.new()
  sun.name = "Sun"
  sun.rotation_degrees = Vector3(-52.0, -35.0, 0.0)
  sun.light_energy = 1.15
  sun.shadow_enabled = true
  add_child(sun)

  var env_node := WorldEnvironment.new()
  env_node.name = "WorldEnvironment"
  var env := Environment.new()
  env.background_mode = Environment.BG_COLOR
  env.background_color = Color(0.025, 0.04, 0.055)
  env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
  env.ambient_light_color = Color(0.68, 0.72, 0.78)
  env.ambient_light_energy = 0.72
  env_node.environment = env
  add_child(env_node)

func _create_roads() -> void:
  for gx in range(-16, 17, 8):
    for gz in range(-18, 19):
      _mark_road(gx, gz)
  for gz in range(-16, 17, 8):
    for gx in range(-18, 19):
      _mark_road(gx, gz)

  for gx in range(-16, 17, 8):
    _make_road(Vector3(gx * CELL_SIZE, 0.06, 0.0), Vector3(ROAD_WIDTH, 0.12, WORLD_SIZE * 0.82))
  for gz in range(-16, 17, 8):
    _make_road(Vector3(0.0, 0.065, gz * CELL_SIZE), Vector3(WORLD_SIZE * 0.82, 0.12, ROAD_WIDTH))

func _mark_road(gx: int, gz: int) -> void:
  road_cells[Vector2i(gx, gz)] = true

func _make_road(pos: Vector3, size: Vector3) -> void:
  var road := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = size
  road.mesh = mesh
  road.position = pos
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.055, 0.06, 0.065)
  mat.roughness = 0.94
  road.material_override = mat
  roads_root.add_child(road)

  if size.x > size.z:
    _make_road_marking(pos, Vector3(size.x, 0.014, 0.045))
  else:
    _make_road_marking(pos, Vector3(0.045, 0.014, size.z))

func _make_road_marking(pos: Vector3, size: Vector3) -> void:
  var stripe := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = size
  stripe.mesh = mesh
  stripe.position = pos + Vector3(0, 0.075, 0)
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.78, 0.72, 0.38)
  stripe.material_override = mat
  roads_root.add_child(stripe)

func _create_zones() -> void:
  for gx in range(-17, 18):
    for gz in range(-17, 18):
      if abs(gx) % 8 == 0 or abs(gz) % 8 == 0:
        continue

      var zone := ZoneType.NONE
      var block := (floori(float(gx + 17) / 8.0) + floori(float(gz + 17) / 8.0)) % 3
      if block == 0:
        zone = ZoneType.RESIDENTIAL
      elif block == 1:
        zone = ZoneType.COMMERCIAL
      else:
        zone = ZoneType.INDUSTRIAL

      zone_map[Vector2i(gx, gz)] = zone
      _make_zone(gx, gz, zone)

func _zone_color(zone: int) -> Color:
  if zone == ZoneType.RESIDENTIAL:
    return Color(0.25, 0.72, 0.38, 0.22)
  if zone == ZoneType.COMMERCIAL:
    return Color(0.25, 0.48, 0.88, 0.22)
  if zone == ZoneType.INDUSTRIAL:
    return Color(0.86, 0.56, 0.22, 0.22)
  return Color(0.0, 0.0, 0.0, 0.0)

func _make_zone(gx: int, gz: int, zone: int) -> void:
  var node := MeshInstance3D.new()
  node.name = "Zone_%d_%d" % [gx, gz]
  var mesh := BoxMesh.new()
  mesh.size = Vector3(CELL_SIZE - 0.10, 0.035, CELL_SIZE - 0.10)
  node.mesh = mesh
  node.position = Vector3(gx * CELL_SIZE, 0.025, gz * CELL_SIZE)

  var mat := StandardMaterial3D.new()
  mat.albedo_color = _zone_color(zone)
  mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  node.material_override = mat

  zones_root.add_child(node)
  zone_visuals[Vector2i(gx, gz)] = node

func _paint_zone_from_screen(screen_pos: Vector2) -> void:
  if screen_pos.y < 140.0:
    return

  var from := camera.project_ray_origin(screen_pos)
  var direction := camera.project_ray_normal(screen_pos)
  if abs(direction.y) < 0.001:
    return

  var distance := -from.y / direction.y
  if distance < 0.0:
    return

  var world := from + direction * distance
  var cell := Vector2i(roundi(world.x / CELL_SIZE), roundi(world.z / CELL_SIZE))

  if not zone_map.has(cell) or road_cells.has(cell):
    return
  if building_map.has(cell):
    return

  zone_map[cell] = selected_zone
  var visual: MeshInstance3D = zone_visuals.get(cell)
  if visual:
    var mat := visual.material_override as StandardMaterial3D
    mat.albedo_color = _zone_color(selected_zone)
  _update_ui()

func _spawn_starter_city() -> void:
  var seeds := [
    Vector2i(-5,-5), Vector2i(-4,-5), Vector2i(-3,-5),
    Vector2i(4,4), Vector2i(5,4), Vector2i(6,4),
    Vector2i(-5,5), Vector2i(-4,5), Vector2i(4,-5),
    Vector2i(3,-5), Vector2i(5,-4)
  ]
  for cell in seeds:
    _grow_building(cell, zone_map.get(cell, ZoneType.RESIDENTIAL), 1)

func _simulate_one_day() -> void:
  day += 1

  var occupied := building_map.size()
  var residential := 0
  var commercial := 0
  var industrial := 0

  for cell in building_map:
    match int(building_map[cell]["zone"]):
      ZoneType.RESIDENTIAL:
        residential += 1
      ZoneType.COMMERCIAL:
        commercial += 1
      ZoneType.INDUSTRIAL:
        industrial += 1

  var capacity := max(1, residential * 18)
  population = min(capacity, population + max(1, int(demand[ZoneType.RESIDENTIAL] * 4.0)))
  jobs = min(max(1, population + commercial * 8 + industrial * 10), commercial * 12 + industrial * 18)

  money += 120 + int(population * 0.8) - occupied * 5
  happiness = clamp(
    happiness
    + (demand[ZoneType.RESIDENTIAL] - 0.5) * 1.5
    - (float(max(0, population - jobs)) / max(1.0, population)) * 0.8,
    0.0,
    100.0
  )

  demand[ZoneType.RESIDENTIAL] = clamp(
    0.78 - float(population) / 1800.0 + (0.65 - happiness / 100.0) * 0.15,
    0.12,
    0.95
  )
  demand[ZoneType.COMMERCIAL] = clamp(0.50 + float(population) / 2400.0, 0.10, 0.92)
  demand[ZoneType.INDUSTRIAL] = clamp(
    0.62 - float(jobs) / 3000.0 + float(max(0, population - jobs)) / 1500.0,
    0.10,
    0.92
  )

  _try_growth()
  _update_ui()

func _try_growth() -> void:
  if building_map.size() >= MAX_BUILDINGS:
    return

  var choices := [ZoneType.RESIDENTIAL, ZoneType.COMMERCIAL, ZoneType.INDUSTRIAL]
  choices.sort_custom(func(a, b): return demand[a] > demand[b])

  for zone in choices:
    if demand[zone] < 0.38:
      continue
    var candidate := _find_growth_cell(zone)
    if candidate == Vector2i(9999, 9999):
      continue

    var level := 1
    if demand[zone] > 0.72 and day % 6 == 0:
      level = 2
    _grow_building(candidate, zone, level)
    break

func _find_growth_cell(zone: int) -> Vector2i:
  var best := Vector2i(9999, 9999)
  var best_score := -9999.0

  for cell in zone_map.keys():
    if zone_map[cell] != zone or building_map.has(cell):
      continue

    var road_distance := _distance_to_road(cell)
    if road_distance > 4:
      continue

    var score := 10.0 - road_distance + randf() * 1.5
    if score > best_score:
      best_score = score
      best = cell

  return best

func _distance_to_road(cell: Vector2i) -> int:
  var best := 99
  for road in road_cells.keys():
    best = min(best, abs(cell.x - road.x) + abs(cell.y - road.y))
  return best

func _grow_building(cell: Vector2i, zone: int, level: int) -> void:
  if building_map.has(cell):
    return

  var b := MeshInstance3D.new()
  b.name = "Building_%d_%d" % [cell.x, cell.y]

  var h := 2.0 + float(level) * 1.6
  var width := CELL_SIZE * 0.76
  if zone == ZoneType.RESIDENTIAL:
    width = CELL_SIZE * 0.70
  elif zone == ZoneType.INDUSTRIAL:
    width = CELL_SIZE * 0.82

  var mesh := BoxMesh.new()
  mesh.size = Vector3(width, h, width)
  b.mesh = mesh
  b.position = Vector3(cell.x * CELL_SIZE, h * 0.5, cell.y * CELL_SIZE)

  var mat := StandardMaterial3D.new()
  if zone == ZoneType.RESIDENTIAL:
    mat.albedo_color = Color(0.58, 0.67, 0.72)
  elif zone == ZoneType.COMMERCIAL:
    mat.albedo_color = Color(0.28, 0.43, 0.62)
  else:
    mat.albedo_color = Color(0.55, 0.48, 0.35)

  mat.roughness = 0.68
  b.material_override = mat
  buildings_root.add_child(b)

  building_map[cell] = {"zone": zone, "level": level}
  if zone == ZoneType.RESIDENTIAL:
    population += 10

func _create_ui() -> void:
  ui = CanvasLayer.new()
  ui.name = "HUD"
  add_child(ui)

  var panel := ColorRect.new()
  panel.position = Vector2(18, 18)
  panel.size = Vector2(390, 175)
  panel.color = Color(0.025, 0.035, 0.05, 0.90)
  ui.add_child(panel)

  info_label = Label.new()
  info_label.position = Vector2(34, 28)
  info_label.add_theme_font_size_override("font_size", 19)
  ui.add_child(info_label)

  demand_label = Label.new()
  demand_label.position = Vector2(34, 104)
  demand_label.add_theme_font_size_override("font_size", 17)
  ui.add_child(demand_label)

  mode_label = Label.new()
  mode_label.position = Vector2(34, 132)
  mode_label.add_theme_font_size_override("font_size", 15)
  ui.add_child(mode_label)

  var residential_button := _make_button("R  Residential", Vector2(18, 205), 145)
  residential_button.pressed.connect(func(): _select_zone(ZoneType.RESIDENTIAL))
  ui.add_child(residential_button)

  var commercial_button := _make_button("C  Commercial", Vector2(170, 205), 145)
  commercial_button.pressed.connect(func(): _select_zone(ZoneType.COMMERCIAL))
  ui.add_child(commercial_button)

  var industrial_button := _make_button("I  Industrial", Vector2(322, 205), 145)
  industrial_button.pressed.connect(func(): _select_zone(ZoneType.INDUSTRIAL))
  ui.add_child(industrial_button)

  var pause_button := _make_button("Pause / Resume", Vector2(18, 257), 190)
  pause_button.pressed.connect(func():
    paused = not paused
    _update_ui()
  )
  ui.add_child(pause_button)

  speed_button = _make_button("Speed 1x", Vector2(218, 257), 160)
  speed_button.pressed.connect(_cycle_speed)
  ui.add_child(speed_button)

  var tip := Label.new()
  tip.position = Vector2(18, 310)
  tip.add_theme_font_size_override("font_size", 15)
  tip.text = "Tap an empty cell to zone it.\nDrag to rotate the city. Mouse wheel = zoom."
  ui.add_child(tip)

func _make_button(title: String, pos: Vector2, width: float) -> Button:
  var button := Button.new()
  button.text = title
  button.position = pos
  button.size = Vector2(width, 42)
  button.add_theme_font_size_override("font_size", 15)
  return button

func _select_zone(zone: int) -> void:
  selected_zone = zone
  _update_ui()

func _cycle_speed() -> void:
  if sim_speed == 1.0:
    sim_speed = 2.0
  elif sim_speed == 2.0:
    sim_speed = 4.0
  else:
    sim_speed = 1.0
  _update_ui()

func _update_ui() -> void:
  if info_label == null:
    return

  info_label.text = "CityBeyond   Day %d\nPopulation %d   Jobs %d\nTreasury $%d   Happiness %d%%" % [
    day, population, jobs, money, int(happiness)
  ]

  demand_label.text = "R %d%%    C %d%%    I %d%%" % [
    int(demand[ZoneType.RESIDENTIAL] * 100),
    int(demand[ZoneType.COMMERCIAL] * 100),
    int(demand[ZoneType.INDUSTRIAL] * 100)
  ]

  var zone_name := "Residential"
  if selected_zone == ZoneType.COMMERCIAL:
    zone_name = "Commercial"
  elif selected_zone == ZoneType.INDUSTRIAL:
    zone_name = "Industrial"

  mode_label.text = "Zone tool: %s   |   %s" % [zone_name, "PAUSED" if paused else "Running"]

  if speed_button:
    speed_button.text = "Speed %dx" % int(sim_speed)
