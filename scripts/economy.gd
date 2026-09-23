extends Node3D

# CityBeyond - Feature Set 3: Economy
# Taxes, city maintenance, land value and treasury feedback.
# The core city script remains responsible for population/building simulation;
# this node owns the economic accounting layer.

const MIN_TAX := 4.0
const MAX_TAX := 18.0

var city: Node
var ui: CanvasLayer
var label: Label
var residential_tax := 10.0
var commercial_tax := 10.0
var industrial_tax := 10.0
var land_value := 50.0
var day_timer := 0.0
var day := 1
var last_income := 0
var last_expense := 0

func _ready() -> void:
  await get_tree().process_frame
  city = get_parent()
  _create_ui()
  _simulate()

func _process(delta: float) -> void:
  if city == null or bool(city.paused):
    return
  day_timer += delta * float(city.sim_speed)
  if day_timer >= 1.0:
    day_timer -= 1.0
    day += 1
    _simulate()

func _simulate() -> void:
  if city == null:
    return

  var population := int(city.population)
  var jobs := int(city.jobs)
  var buildings: Dictionary = city.building_map

  var residential_units := 0
  var commercial_buildings := 0
  var industrial_buildings := 0
  for cell in buildings:
    var data: Dictionary = buildings[cell]
    var zone := int(data["zone"])
    var level := int(data["level"])
    if zone == city.ZoneType.RESIDENTIAL:
      residential_units += 18 * level
    elif zone == city.ZoneType.COMMERCIAL:
      commercial_buildings += 1
    elif zone == city.ZoneType.INDUSTRIAL:
      industrial_buildings += 1

  var residential_revenue := int(residential_units * residential_tax * 0.22)
  var commercial_revenue := int(commercial_buildings * (85.0 + population * 0.045) * commercial_tax / 10.0)
  var industrial_revenue := int(industrial_buildings * (105.0 + jobs * 0.025) * industrial_tax / 10.0)
  last_income = 120 + residential_revenue + commercial_revenue + industrial_revenue

  var road_maintenance := int(city.road_cells.size() * 1.2)
  var building_services := buildings.size() * 4
  var utility_maintenance := buildings.size() * 2
  last_expense = 80 + road_maintenance + building_services + utility_maintenance

  city.monthly_income = last_income
  city.monthly_expense = last_expense
  city.money += last_income - last_expense

  var demand_average := (float(city.demand[city.ZoneType.RESIDENTIAL]) + float(city.demand[city.ZoneType.COMMERCIAL]) + float(city.demand[city.ZoneType.INDUSTRIAL])) / 3.0
  var tax_penalty := ((residential_tax + commercial_tax + industrial_tax) / 3.0 - 10.0) * 0.7
  var service_bonus := 0.0
  if buildings.size() > 0:
    service_bonus = 6.0 if _utility_services_online() else -10.0
  land_value = clamp(50.0 + float(city.happiness) * 0.35 + demand_average * 20.0 + service_bonus - tax_penalty, 5.0, 100.0)

  # Economy feeds back into demand and happiness: higher taxes reduce growth pressure;
  # strong land value and balanced services support residential demand.
  city.demand[city.ZoneType.RESIDENTIAL] = clamp(
    float(city.demand[city.ZoneType.RESIDENTIAL]) - tax_penalty * 0.003 + (land_value - 50.0) * 0.0007,
    0.10, 0.95
  )
  city.happiness = clamp(float(city.happiness) - tax_penalty * 0.015, 0.0, 100.0)

  _update_ui()

func _utility_services_online() -> bool:
  var utilities := get_parent().get_node_or_null("Utilities")
  if utilities == null:
    return true
  return not bool(utilities.outage)

func _change_tax(kind: String, delta: float) -> void:
  if kind == "R":
    residential_tax = clamp(residential_tax + delta, MIN_TAX, MAX_TAX)
  elif kind == "C":
    commercial_tax = clamp(commercial_tax + delta, MIN_TAX, MAX_TAX)
  else:
    industrial_tax = clamp(industrial_tax + delta, MIN_TAX, MAX_TAX)
  _update_ui()

func _create_ui() -> void:
  ui = CanvasLayer.new()
  ui.name = "EconomyHUD"
  add_child(ui)

  var panel := ColorRect.new()
  panel.position = Vector2(455, 18)
  panel.size = Vector2(350, 190)
  panel.color = Color(0.025, 0.035, 0.05, 0.92)
  ui.add_child(panel)

  label = Label.new()
  label.position = Vector2(470, 28)
  label.add_theme_font_size_override("font_size", 15)
  ui.add_child(label)

  _make_button("R Tax -", Vector2(470, 118), "R", -1.0)
  _make_button("R Tax +", Vector2(548, 118), "R", 1.0)
  _make_button("C Tax -", Vector2(626, 118), "C", -1.0)
  _make_button("C Tax +", Vector2(704, 118), "C", 1.0)
  _make_button("I Tax -", Vector2(470, 164), "I", -1.0)
  _make_button("I Tax +", Vector2(548, 164), "I", 1.0)

func _make_button(title: String, pos: Vector2, kind: String, delta: float) -> void:
  var button := Button.new()
  button.text = title
  button.position = pos
  button.size = Vector2(72, 34)
  button.add_theme_font_size_override("font_size", 12)
  button.pressed.connect(func(): _change_tax(kind, delta))
  ui.add_child(button)

func _update_ui() -> void:
  if label == null or city == null:
    return
  label.text = "ECONOMY\nTax  R %d%%   C %d%%   I %d%%\nIncome +$%d   Expense -$%d\nLand value %d/100   Treasury $%d" % [
    int(residential_tax), int(commercial_tax), int(industrial_tax),
    last_income, last_expense, int(land_value), int(city.money)
  ]
