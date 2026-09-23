# CityBeyond

CityBeyond is a mobile-first 3D city-building simulator made with Godot 4.

## Feature Set 1 — Core City Engine — COMPLETE

- 48x48 build grid
- 3D ground and readable cell grid
- isometric-style orbit camera
- touch drag camera rotation
- mouse rotation and zoom
- connected arterial road grid
- R/C/I zoning
- tap-to-zone
- automatic demand-driven growth
- building levels and upgrades
- population, jobs, treasury and happiness simulation
- pause/resume and 1x/2x/4x simulation speed
- live HUD and selected-cell feedback

## Feature Set 2 — Utilities — COMPLETE

The current main scene now includes a dedicated utilities simulation:

- Power network backbone
- Water network backbone
- Sewage network backbone
- Utility service coverage radius
- Per-building power demand
- Per-building water demand
- Per-building sewage load
- Utility capacity limits
- Automatic capacity expansion as the city grows
- Unserved-building detection
- Visible utility network lines
- Utilities HUD showing demand/capacity and served buildings
- Building visual feedback for utility coverage
- Utility outage/unsatisfied-service state

### Current limitation

Buildings are still procedural placeholder geometry. Production-quality 3D assets, player-placeable utility branches, service buildings and deeper network routing are later milestones.

## Android workflow

The project is configured for Godot 4 and the OpenGL Compatibility renderer for broad Android startup compatibility.

## Feature Set 3 — Economy — COMPLETE

The current main scene now includes a dedicated economy simulation:

- Residential, commercial and industrial tax rates
- In-game tax controls from 4% to 18%
- City income and operating expenses
- Road, building-service and utility maintenance costs
- Treasury accounting
- Land value simulation
- Tax impact on residential demand and happiness
- Utility-service impact on land value
- Economy HUD with tax rates, income, expenses, land value and treasury

### Current limitation

The economy layer is intentionally lightweight at this milestone. Deeper budget categories, loans, unique city policies, trade, imports/exports and detailed household/business accounting are later simulation work.

## Feature Set 4 — Traffic & Transport — COMPLETE

The current main scene now includes a lightweight mobile-friendly traffic layer:

- Moving road vehicles
- Traffic volume driven by population, jobs and buildings
- Congestion calculation and speed reduction
- Intersection traffic-light visuals
- Public bus vehicles
- Bus ridership simulation
- Traffic & Transport HUD
- Traffic state feedback: free flow, busy and heavy congestion

### Current limitation

Traffic currently uses a procedural road-loop model rather than full lane-by-lane pathfinding. Junction routing, turning lanes, accidents, parking, pedestrian simulation and player-placeable transit routes are later traffic milestones.

## Planned feature sets

5. Services: police, fire, healthcare, education and garbage.

4. Traffic & transport: vehicles, intersections, congestion and public transport.

5. Services: police, fire, healthcare, education and garbage.

6. Advanced city simulation: pollution, crime, disasters, terrain, weather and larger maps.

7. Visual polish: production 3D buildings, props, roads, effects and mobile optimization.

8. Finalization: save/load, settings, performance pass and Android APK/AAB packaging.
