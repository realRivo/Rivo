extends Node3D

# CityBeyond - Feature Set 4: Traffic & Transport
# Lightweight mobile-friendly traffic simulation with moving vehicles,
# congestion, intersections, traffic lights and a basic public bus service.

const ROAD_COORDS := [-40.0, -20.0, 0.0, 20.0, 40.0]
const MAX_VEHICLES := 70
const VEHICLE_SPEED := 7.5
const BUS_SPEED := 5.2

var city: Node
var vehicle_root: Node3D
var bus_root: Node3D
var light_root: Node3D
var ui: CanvasLayer
var label: Label
var vehicles: Array = []
var buses: Array = []
var day_timer := 0.0
var day := 1
var congestion := 0.0
var average_speed := VEHICLE_SPEED
var trips_per_day := 0
var bus_riders := 0

func _ready() -> void:
  await get_tree().process_frame
  city = get_parent()
  vehicle_root = Node3D.new()
  vehicle_root.name = "TrafficVehicles"
  add_child(vehicle_root)
  bus_root = Node3D.new()
  bus_root.name = "PublicBuses"
  add_child(bus_root)
  light_root = Node3D.new()
  light_root.name = "TrafficLights"
  add_child(light_root)
  _create_intersections()
  _create_initial_traffic()
  _create_buses()
  _create_ui()
  _simulate()

func _process(delta: float) -> void:
  if city == null or bool(city.paused):
    return
  _move_vehicles(delta * float(city.sim_speed))
  _move_buses(delta * float(city.sim_speed))
  day_timer += delta * float(city.sim_speed)
  if day_timer >= 1.0:
    day_timer -= 1.0
    day += 1
    _simulate()

func _create_initial_traffic() -> void:
  for i in range(18):
    _spawn_vehicle(i)

func _spawn_vehicle(index: int) -> void:
  var car := MeshInstance3D.new()
  car.name = "Car_%d" % index
  var mesh := BoxMesh.new()
  mesh.size = Vector3(0.62, 0.32, 1.15)
  car.mesh = mesh
  var mat := StandardMaterial3D.new()
  mat.albedo_color = Color(0.18 + randf() * 0.55, 0.20 + randf() * 0.45, 0.24 + randf() * 0.40)
  mat.roughness = 0.65
  car.material_override = mat
  var horizontal := index % 2 == 0
  var lane := ROAD_COORDS[index % ROAD_COORDS.size()]
  var progress := float((index * 17) % 100) / 100.0
  if horizontal:
    car.position = Vector3(-50.0 + progress * 100.0, 0.30, lane + 0.28)
    car.rotation_degrees.y = 90.0
  else:
    car.position = Vector3(lane + 0.28, 0.30, -50.0 + progress * 100.0)
    car.rotation_degrees.y = 0.0
  vehicle_root.add_child(car)
  vehicles.append({"node": car, "horizontal": horizontal, "lane": lane, "offset": progress * 100.0})

func _move_vehicles(delta: float) -> void:
  var speed_factor := clamp(1.0 - congestion * 0.62, 0.28, 1.0)
  for data in vehicles:
    var car: MeshInstance3D = data["node"]
    if not is_instance_valid(car):
      continue
    var horizontal: bool = data["horizontal"]
    var distance: float = float(data["offset"]) + VEHICLE_SPEED * speed_factor * delta
    if distance >= 100.0:
      distance -= 100.0
    data["offset"] = distance
    if horizontal:
      car.position.x = -50.0 + distance
    else:
      car.position.z = -50.0 + distance

func _create_buses() -> void:
  for i in range(3):
    var bus := MeshInstance3D.new()
    bus.name = "Bus_%d" % i
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.85, 0.48, 1.9)
    bus.mesh = mesh
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.82, 0.60, 0.12)
    mat.roughness = 0.6
    bus.material_override = mat
    bus.position = Vector3(-50.0 + i * 34.0, 0.42, 0.55)
    bus.rotation_degrees.y = 90.0
    bus_root.add_child(bus)
    buses.append({"node": bus, "offset": float(i * 34.0)})

func _move_buses(delta: float) -> void:
  for data in buses:
    var bus: MeshInstance3D = data["node"]
    var distance: float = float(data["offset"]) + BUS_SPEED * delta
    if distance >= 100.0:
      distance -= 100.0
    data["offset"] = distance
    bus.position.x = -50.0 + distance

func _create_intersections() -> void:
  for x in ROAD_COORDS:
    for z in ROAD_COORDS:
      var pole := MeshInstance3D.new()
      var mesh := BoxMesh.new()
      mesh.size = Vector3(0.16, 1.1, 0.16)
      pole.mesh = mesh
      pole.position = Vector3(x + 0.82, 0.58, z + 0.82)
      var mat := StandardMaterial3D.new()
      mat.albedo_color = Color(0.12, 0.12, 0.13)
      pole.material_override = mat
      light_root.add_child(pole)
      for lamp_z in [-0.25, 0.0, 0.25]:
        var lamp := MeshInstance3D.new()
        var lm := SphereMesh.new()
        lm.radius = 0.07
        lm.height = 0.14
        lamp.mesh = lm
        lamp.position = Vector3(x + 0.82, 0.70 + lamp_z, z + 0.82)
        var lmat := StandardMaterial3D.new()
        lmat.albedo_color = Color(0.75, 0.08, 0.05) if int(abs(x + z)) % 40 == 0 else Color(0.08, 0.72, 0.20)
        lmat.emission_enabled = true
        lmat.emission = lmat.albedo_color * 0.35
        lamp.material_override = lmat
        light_root.add_child(lamp)

func _simulate() -> void:
  if city == null:
    return
  var population := int(city.population)
  var jobs := int(city.jobs)
  var building_count := city.building_map.size()
  var road_capacity := max(1, city.road_cells.size() / 7)
  var demand_factor := float(population + jobs) / 120.0
  var vehicle_target := clampi(12 + int(demand_factor * 10.0) + building_count / 8, 12, MAX_VEHICLES)
  while vehicles.size() < vehicle_target:
    _spawn_vehicle(vehicles.size())
  while vehicles.size() > vehicle_target:
    var data = vehicles.pop_back()
    if is_instance_valid(data["node"]):
      data["node"].queue_free()

  var capacity_pressure := float(vehicle_target) / float(road_capacity)
  congestion = clamp((capacity_pressure - 0.55) * 0.95, 0.0, 1.0)
  average_speed = VEHICLE_SPEED * clamp(1.0 - congestion * 0.62, 0.28, 1.0)
  trips_per_day = vehicle_target * 8 + population / 4
  bus_riders = int(population * (0.08 + congestion * 0.10))

  _update_ui()

func _create_ui() -> void:
  ui = CanvasLayer.new()
  ui.name = "TrafficHUD"
  add_child(ui)
  var panel := ColorRect.new()
  panel.position = Vector2(455, 220)
  panel.size = Vector2(350, 165)
  panel.color = Color(0.025, 0.035, 0.05, 0.92)
  ui.add_child(panel)
  label = Label.new()
  label.position = Vector2(470, 232)
  label.add_theme_font_size_override("font_size", 15)
  ui.add_child(label)

func _update_ui() -> void:
  if label == null or city == null:
    return
  var state := "Free flow"
  if congestion >= 0.70:
    state = "Heavy congestion"
  elif congestion >= 0.40:
    state = "Busy"
  label.text = "TRAFFIC & TRANSPORT\nVehicles %d   Avg speed %.1f\nCongestion %d%%   %s\nTrips/day %d   Bus riders %d" % [
    vehicles.size(), average_speed, int(congestion * 100.0), state, trips_per_day, bus_riders
  ]


var bus_route_enabled := true

func toggle_route() -> void:
  bus_route_enabled = not bus_route_enabled
  for data in buses:
    var bus: MeshInstance3D = data["node"]
    bus.visible = bus_route_enabled
