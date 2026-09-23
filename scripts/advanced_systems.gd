extends Node3D

# CityBeyond - Feature Set 5: City Services, Environment, Disasters, Save/Load
# Adds police, fire, healthcare, education and garbage coverage; pollution/crime;
# service effects on happiness/land value; random emergencies; and persistent save/load.

const COVERAGE := {
  "Police": 22.0,
  "Fire": 20.0,
  "Health": 18.0,
  "Education": 20.0,
  "Garbage": 24.0
}

var city: Node
var ui: CanvasLayer
var label: Label
var day_timer := 0.0
var day := 1
var pollution := 8.0
var crime := 5.0
var service_score := 0.0
var emergency_cooldown := 0.0
var last_event := "No active emergency."
var service_roots: Dictionary = {}
var service_points: Dictionary = {
  "Police": [Vector3(-30, 0.45, -30)],
  "Fire": [Vector3(30, 0.45, -30)],
  "Health": [Vector3(-30, 0.45, 30)],
  "Education": [Vector3(30, 0.45, 30)],
  "Garbage": [Vector3(0, 0.45, 30)]
}

func _ready() -> void:
  await get_tree().process_frame
  city = get_parent()
  _create_service_visuals()
  _create_ui()
  _simulate()

func _process(delta: float) -> void:
  if city == null or bool(city.paused):
    return
  day_timer += delta * float(city.sim_speed)
  emergency_cooldown = max(0.0, emergency_cooldown - delta * float(city.sim_speed))
  if day_timer >= 1.0:
    day_timer -= 1.0
    day += 1
    _simulate()

func _create_service_visuals() -> void:
  for service in service_points.keys():
    var root := Node3D.new()
    root.name = service + "Stations"
    add_child(root)
    service_roots[service] = root
    for pos in service_points[service]:
      var building := MeshInstance3D.new()
      building.name = service + "Station"
      var mesh := BoxMesh.new()
      mesh.size = Vector3(2.2, 1.6, 2.2)
      building.mesh = mesh
      building.position = pos
      var mat := StandardMaterial3D.new()
      mat.albedo_color = _service_color(service)
      mat.roughness = 0.65
      building.material_override = mat
      root.add_child(building)

func _service_color(service: String) -> Color:
  match service:
    "Police": return Color(0.15, 0.30, 0.72)
    "Fire": return Color(0.82, 0.20, 0.10)
    "Health": return Color(0.85, 0.88, 0.90)
    "Education": return Color(0.25, 0.62, 0.30)
    "Garbage": return Color(0.55, 0.48, 0.30)
  return Color.WHITE

func _coverage_for(service: String, pos: Vector3) -> float:
  var radius: float = float(COVERAGE.get(service, 20.0))
  var best := 0.0
  for point in service_points.get(service, []):
    var d := pos.distance_to(point)
    best = max(best, clamp(1.0 - d / radius, 0.0, 1.0))
  return best

func _simulate() -> void:
  if city == null:
    return
  var buildings_root := city.get_node_or_null("City/Buildings")
  var building_count := city.building_map.size()
  if buildings_root == null:
    return

  var coverage_total := 0.0
  var pollution_sum := 0.0
  var crime_pressure := 0.0
  var uncollected := 0.0

  for b in buildings_root.get_children():
    if not b is MeshInstance3D:
      continue
    var pos := (b as Node3D).global_position
    var zone := ZoneTypeToInt(city, b.name)
    var service_average := 0.0
    for service in COVERAGE.keys():
      service_average += _coverage_for(service, pos)
    service_average /= float(COVERAGE.size())
    coverage_total += service_average

    var industrial := zone == city.ZoneType.INDUSTRIAL
    pollution_sum += 1.8 if industrial else 0.35
    crime_pressure += 1.0 - _coverage_for("Police", pos)
    uncollected += 1.0 - _coverage_for("Garbage", pos)

  var average_coverage := coverage_total / max(1.0, float(building_count))
  pollution = clamp(pollution_sum * 0.55 + float(city.population) * 0.002, 0.0, 100.0)
  crime = clamp(3.0 + crime_pressure * 2.8 - _coverage_for("Police", Vector3.ZERO) * 8.0, 0.0, 100.0)
  service_score = average_coverage * 100.0

  var service_happiness := (average_coverage - 0.5) * 8.0
  var environment_penalty := pollution * 0.025 + crime * 0.035
  city.happiness = clamp(float(city.happiness) + service_happiness * 0.08 - environment_penalty * 0.08, 0.0, 100.0)

  var economy := get_node_or_null("../Economy")
  if economy:
    economy.land_value = clamp(float(economy.land_value) + service_happiness * 0.12 - pollution * 0.012 - crime * 0.010, 5.0, 100.0)

  # Industrial production creates additional garbage/pollution pressure.
  if uncollected > 2.0:
    last_event = "Garbage pressure is rising in underserved districts."

  if emergency_cooldown <= 0.0 and building_count > 18 and randf() < 0.018:
    _trigger_emergency()
    emergency_cooldown = 22.0

  _update_ui()

func ZoneTypeToInt(city_node: Node, building_name: String) -> int:
  var parts := building_name.split("_")
  if parts.size() >= 3:
    var cell := Vector2i(int(parts[1]), int(parts[2]))
    if city_node.building_map.has(cell):
      return int(city_node.building_map[cell]["zone"])
  return city_node.ZoneType.RESIDENTIAL

func _trigger_emergency() -> void:
  var buildings_root := city.get_node_or_null("City/Buildings")
  if buildings_root == null or buildings_root.get_child_count() == 0:
    return
  var choices := buildings_root.get_children()
  var target = choices[randi() % choices.size()]
  if target is MeshInstance3D:
    var cell := Vector2i(roundi(target.position.x / city.CELL_SIZE), roundi(target.position.z / city.CELL_SIZE))
    last_event = "Emergency: building damage near %d,%d. Services responded." % [cell.x, cell.y]
    city.happiness = clamp(float(city.happiness) - 1.5, 0.0, 100.0)
    if city.building_map.has(cell):
      var data: Dictionary = city.building_map[cell]
      data["damaged"] = true
      city.building_map[cell] = data
      (target as MeshInstance3D).scale = Vector3(0.88, 0.72, 0.88)

func _repair_emergency() -> void:
  var buildings_root := city.get_node_or_null("City/Buildings")
  if buildings_root:
    for b in buildings_root.get_children():
      if b is MeshInstance3D:
        var cell := Vector2i(roundi((b as Node3D).position.x / city.CELL_SIZE), roundi((b as Node3D).position.z / city.CELL_SIZE))
        if city.building_map.has(cell) and bool(city.building_map[cell].get("damaged", false)):
          b.scale = Vector3.ONE
          var data: Dictionary = city.building_map[cell]
          data["damaged"] = false
          city.building_map[cell] = data
  last_event = "Emergency response complete."

func _save_game() -> void:
  var data := {
    "day": city.day,
    "population": city.population,
    "jobs": city.jobs,
    "money": city.money,
    "happiness": city.happiness,
    "sim_speed": city.sim_speed,
    "paused": city.paused,
    "selected_zone": city.selected_zone,
    "zones": {},
    "buildings": []
  }
  for cell in city.zone_map:
    data["zones"][str(cell.x) + "," + str(cell.y)] = int(city.zone_map[cell])
  for cell in city.building_map:
    var b: Dictionary = city.building_map[cell]
    data["buildings"].append({
      "x": cell.x, "y": cell.y, "zone": int(b["zone"]), "level": int(b["level"]),
      "damaged": bool(b.get("damaged", false))
    })
  var file := FileAccess.open("user://citybeyond_save.json", FileAccess.WRITE)
  if file:
    file.store_string(JSON.stringify(data))
    file.close()
    last_event = "City saved to device."

func _load_game() -> void:
  if not FileAccess.file_exists("user://citybeyond_save.json"):
    last_event = "No save found yet."
    return
  var file := FileAccess.open("user://citybeyond_save.json", FileAccess.READ)
  var parsed = JSON.parse_string(file.get_as_text())
  file.close()
  if typeof(parsed) != TYPE_DICTIONARY:
    last_event = "Save file could not be read."
    return

  city.day = int(parsed.get("day", 1))
  city.population = int(parsed.get("population", 0))
  city.jobs = int(parsed.get("jobs", 0))
  city.money = int(parsed.get("money", city.STARTING_MONEY))
  city.happiness = float(parsed.get("happiness", 62.0))
  city.sim_speed = float(parsed.get("sim_speed", 1.0))
  city.paused = bool(parsed.get("paused", false))
  city.selected_zone = int(parsed.get("selected_zone", city.ZoneType.RESIDENTIAL))

  for cell in city.building_map.keys():
    var node = city.building_nodes.get(cell)
    if node and is_instance_valid(node):
      node.queue_free()
  city.building_map.clear()
  city.building_nodes.clear()

  for key in parsed.get("zones", {}):
    var parts := String(key).split(",")
    if parts.size() == 2:
      city.zone_map[Vector2i(int(parts[0]), int(parts[1]))] = int(parsed["zones"][key])

  for b in parsed.get("buildings", []):
    var cell := Vector2i(int(b["x"]), int(b["y"]))
    city._grow_building(cell, int(b["zone"]), int(b["level"]))
    if city.building_map.has(cell):
      city.building_map[cell]["damaged"] = bool(b.get("damaged", false))

  last_event = "City loaded from device."
  _update_ui()

func _create_ui() -> void:
  ui = CanvasLayer.new()
  ui.name = "ServicesHUD"
  add_child(ui)

  var panel := ColorRect.new()
  panel.position = Vector2(825, 18)
  panel.size = Vector2(430, 255)
  panel.color = Color(0.025, 0.035, 0.05, 0.93)
  ui.add_child(panel)

  label = Label.new()
  label.position = Vector2(840, 30)
  label.add_theme_font_size_override("font_size", 15)
  ui.add_child(label)

  _button("SAVE CITY", Vector2(840, 145), _save_game)
  _button("LOAD CITY", Vector2(955, 145), _load_game)
  _button("REPAIR", Vector2(1070, 145), _repair_emergency)
  _button("EMERGENCY TEST", Vector2(840, 190), _trigger_emergency)
  _button("BUS LOOP", Vector2(1010, 190), _toggle_bus_loop)

func _button(title: String, pos: Vector2, callback: Callable) -> void:
  var button := Button.new()
  button.text = title
  button.position = pos
  button.size = Vector2(105, 36)
  button.add_theme_font_size_override("font_size", 12)
  button.pressed.connect(callback)
  ui.add_child(button)

func _toggle_bus_loop() -> void:
  var traffic := get_node_or_null("../Traffic")
  if traffic and traffic.has_method("toggle_route"):
    traffic.toggle_route()
    last_event = "Bus route loop toggled."

func _update_ui() -> void:
  if label == null or city == null:
    return
  label.text = "CITY SERVICES & ENVIRONMENT\nPolice  •  Fire  •  Health  •  Education  •  Garbage\nService coverage %d%%   Pollution %d   Crime %d\nHappiness %d%%   Land value %d/100\n%s" % [
    int(service_score), int(pollution), int(crime), int(city.happiness),
    int(get_node_or_null("../Economy").land_value) if get_node_or_null("../Economy") else 0,
    last_event
  ]
