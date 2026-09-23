extends Node3D

# CityBeyond - Feature Set 2: Utilities
# Power, water and sewage networks with service coverage, capacity and outages.

const GRID_SIZE := 48
const CELL_SIZE := 2.5
const MAX_CAPACITY := 650
const COVERAGE_RADIUS := 17.0

var buildings_root: Node3D
var power_root: Node3D
var water_root: Node3D
var sewage_root: Node3D
var ui: CanvasLayer
var label: Label
var day_timer := 0.0
var day := 1

var power_supply := 520
var water_supply := 520
var sewage_capacity := 520
var power_demand := 0
var water_demand := 0
var sewage_load := 0
var outage := false

func _ready() -> void:
  await get_tree().process_frame
  buildings_root = get_parent().get_node_or_null("City/Buildings")
  _create_network_visuals()
  _create_ui()
  _simulate()

func _process(delta: float) -> void:
  day_timer += delta
  if day_timer >= 1.0:
    day_timer -= 1.0
    day += 1
    _simulate()

func _create_network_visuals() -> void:
  power_root = Node3D.new()
  power_root.name = "PowerNetwork"
  add_child(power_root)
  water_root = Node3D.new()
  water_root.name = "WaterNetwork"
  add_child(water_root)
  sewage_root = Node3D.new()
  sewage_root.name = "SewageNetwork"
  add_child(sewage_root)

  # Three visible trunk networks. These are the utility backbone for the first
  # milestone; later utility sets can add player-placeable branches.
  _make_network_line(power_root, Vector3(-42, 0.18, 0), Vector3(42, 0.18, 0), Color(0.92, 0.72, 0.18))
  _make_network_line(power_root, Vector3(0, 0.18, -42), Vector3(0, 0.18, 42), Color(0.92, 0.72, 0.18))
  _make_network_line(water_root, Vector3(-42, 0.21, 5), Vector3(42, 0.21, 5), Color(0.18, 0.48, 0.95))
  _make_network_line(water_root, Vector3(-5, 0.21, -42), Vector3(-5, 0.21, 42), Color(0.18, 0.48, 0.95))
  _make_network_line(sewage_root, Vector3(-42, 0.24, -5), Vector3(42, 0.24, -5), Color(0.48, 0.58, 0.42))
  _make_network_line(sewage_root, Vector3(5, 0.24, -42), Vector3(5, 0.24, 42), Color(0.48, 0.58, 0.42))

func _make_network_line(root: Node3D, a: Vector3, b: Vector3, color: Color) -> void:
  var line := MeshInstance3D.new()
  var mesh := BoxMesh.new()
  mesh.size = Vector3(abs(b.x - a.x) if abs(b.x - a.x) > 0.1 else 0.10, 0.06, abs(b.z - a.z) if abs(b.z - a.z) > 0.1 else 0.10)
  line.mesh = mesh
  line.position = (a + b) * 0.5
  var mat := StandardMaterial3D.new()
  mat.albedo_color = color
  mat.emission_enabled = true
  mat.emission = color * 0.35
  line.material_override = mat
  root.add_child(line)

func _simulate() -> void:
  power_demand = 0
  water_demand = 0
  sewage_load = 0
  var covered := 0
  var total := 0

  if buildings_root:
    for b in buildings_root.get_children():
      if not b is MeshInstance3D:
        continue
      total += 1
      var level := 1
      var h := float((b as MeshInstance3D).mesh.size.y)
      level = max(1, int(round((h - 2.0) / 1.6)))
      var position := (b as Node3D).global_position
      var supplied := _has_utility_coverage(position)
      if supplied:
        covered += 1
        power_demand += 2 + level
        water_demand += 2 + level
        sewage_load += 2 + level
      else:
        # Unserved buildings still create demand, but count as an outage.
        power_demand += 1 + level
        water_demand += 1 + level
        sewage_load += 1 + level

  outage = power_demand > power_supply or water_demand > water_supply or sewage_load > sewage_capacity or covered < total

  # Small automatic capacity investment keeps a growing city from immediately
  # failing while still making utilities a real simulation constraint.
  if day % 20 == 0 and power_supply < MAX_CAPACITY:
    power_supply += 20
    water_supply += 20
    sewage_capacity += 20

  _update_building_visuals()
  _update_ui()

func _has_utility_coverage(pos: Vector3) -> bool:
  var power_distance := min(abs(pos.x), abs(pos.z))
  var water_distance := min(abs(pos.z - 5.0), abs(pos.x + 5.0))
  var sewage_distance := min(abs(pos.z + 5.0), abs(pos.x - 5.0))
  return power_distance <= COVERAGE_RADIUS and water_distance <= COVERAGE_RADIUS and sewage_distance <= COVERAGE_RADIUS

func _update_building_visuals() -> void:
  if not buildings_root:
    return
  for b in buildings_root.get_children():
    if not b is MeshInstance3D:
      continue
    var mesh_instance := b as MeshInstance3D
    if _has_utility_coverage(mesh_instance.global_position):
      mesh_instance.transparency = 0.0
    else:
      # A subtle fade signals an unserved building without hiding it.
      mesh_instance.transparency = 0.12

func _create_ui() -> void:
  ui = CanvasLayer.new()
  ui.name = "UtilitiesHUD"
  add_child(ui)

  var panel := ColorRect.new()
  panel.position = Vector2(18, 375)
  panel.size = Vector2(420, 112)
  panel.color = Color(0.02, 0.04, 0.055, 0.92)
  ui.add_child(panel)

  label = Label.new()
  label.position = Vector2(32, 386)
  label.add_theme_font_size_override("font_size", 15)
  ui.add_child(label)

func _update_ui() -> void:
  if not label:
    return
  var total := buildings_root.get_child_count() if buildings_root else 0
  var served := 0
  if buildings_root:
    for b in buildings_root.get_children():
      if b is MeshInstance3D and _has_utility_coverage((b as Node3D).global_position):
        served += 1
  label.text = "UTILITIES  •  Day %d\nPower  %d/%d   Water  %d/%d   Sewage  %d/%d\nCoverage  %d/%d buildings   %s" % [
    day, power_demand, power_supply, water_demand, water_supply, sewage_load, sewage_capacity,
    served, total, "OUTAGE / UNSERVED" if outage else "ALL SERVICES ONLINE"
  ]
