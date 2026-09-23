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

- Power, water and sewage backbone networks
- Utility coverage radius
- Per-building utility demand
- Capacity limits and automatic capacity expansion
- Unserved-building detection and visual feedback
- Utility outage state and HUD

## Feature Set 3 — Economy — COMPLETE

- Residential, commercial and industrial taxes
- Tax controls from 4% to 18%
- Income and operating expenses
- Road, building-service and utility maintenance
- Treasury accounting
- Land value
- Tax/service feedback into demand and happiness

## Feature Set 4 — Traffic & Transport — COMPLETE

- Moving road vehicles
- Traffic volume from population/jobs/buildings
- Congestion and speed reduction
- Intersection traffic-light visuals
- Public buses and bus ridership
- Toggleable bus loop
- Traffic HUD

## Feature Set 5 — Services, Environment, Emergencies & Save/Load — COMPLETE

- Police, fire, healthcare, education and garbage service stations
- Coverage scoring for each service
- Service effects on happiness and land value
- Pollution simulation
- Crime pressure simulation
- Random emergency events and manual emergency test
- Emergency repair action
- Persistent JSON save/load on the Android device
- Service/environment HUD

## Current architecture

- scripts/city_beyond.gd — core grid, zoning, growth, population/jobs, camera and city HUD
- scripts/utilities.gd — power/water/sewage
- scripts/economy.gd — taxes, treasury and land value
- scripts/traffic.gd — vehicles, congestion and buses
- scripts/advanced_systems.gd — services, pollution, crime, emergencies and save/load

## Known next production milestones

The simulation foundation is now in place, but these are still separate production tasks rather than simple toggles:

1. Replace procedural box buildings with the uploaded CC0/KayKit/SBS 3D assets and create residential/commercial/industrial variants.
2. Add real road meshes, intersections, lane-level routing, turning lanes, parking and pedestrian agents.
3. Add player-placeable utility branches and service stations.
4. Add terrain heightmaps, water bodies, weather and larger streamed maps.
5. Add richer disasters such as fires, floods and storms with response simulation.
6. Add deeper public transport: player-created bus routes, stops, route demand and later rail/metro.
7. Add detailed households/businesses, imports/exports, loans, policies and service budgets.
8. Add LOD/instancing, batching, texture compression and mobile performance profiling.
9. Final Android save/settings pass and signed APK/AAB packaging.

## Android workflow

The project is configured for Godot 4 and the OpenGL Compatibility renderer for broad Android startup compatibility.
