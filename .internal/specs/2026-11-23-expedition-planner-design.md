# TonyLocuras Expedition Planner — Design Spec

Date: 2026-11-23 · Status: approved by user (design stage)

## Goal
Native app for planning mountain, alpinism, caving and survival routes, inspired by the Nomad Face
"Prepara tu ruta" web flow (Dónde → Ruta → Análisis), but much broader. Personal use first; audience later.

## Decisions (from user)
- Tech: Flutter. Targets v1: Android + Windows. iOS/Mac/web kept possible.
- Sync: cloud backend (Supabase) with user account, offline-first, sync PC/mobile/tablet.
- Location: independent folder `expedition-planner/`; existing web (index.html, admin.html, datos.js) untouched.
- Language: Spanish. Style: dark tactical, high contrast, large touch targets (gloves), red night mode.
- Data: free APIs by default (Open-Meteo, OpenStreetMap, open elevation); premium optional.
- v1 features: offline maps + GPX, weather/UV/temp by altitude, gear checklist, safety/emergency plan.
- Extras: recording-expedition planner, specific risks (mines, dams, riverbeds), logbook/stats, AI route assistant.
- Flow: guided 3-step wizard + expert map mode.

## Reference video findings (37.7 s, 720x1280)
Step 1 Dónde: use location or postal code, nearby routes list on map. Step 2 Ruta: map, km, D+, max alt,
time, activity type (senderismo, trail, raquetas/esquí, bici, alpinismo), GPX upload/draw, "Analizar ruta".
Step 3 Análisis: pick day (multi-day forecast with snow, temp, UV, best day), summary (minutes to burn,
SPF reapplications), UV/altitude profile, "what you'll find" warnings (snow reflection, freezing level,
wind chill), generated pack list, send by WhatsApp.

## Modules
1. Maps & routes: offline topo, GPX import/export/record/draw, altitude profile, slope, time model.
2. Weather by altitude: hourly slots, UV, wind, rain, apparent temp, lapse-rate by elevation, daylight window.
3. Specific risks: upstream rain for riverbeds/dams, heat/water per km for desert, mine-gallery notes.
4. Gear: generated pack list by route/weather/type; own gear inventory incl. camera/drone batteries/cards.
5. Safety: emergency plan, turnaround deadline, check-in to contact, evacuation coordinates.
6. Recording expedition: golden hour, shot plan, drone rules, link to scripts.
7. Logbook & stats: trips, cumulative gain, gear used.
8. AI assistant: server-side function reading route + forecast + gear, proposes plan and pack list.

## Architecture
Layers: data (APIs, GPX, storage) → domain (pure, unit-tested: time, risk, packing, weather math) → ui.
Offline-first local DB (Drift/SQLite), sync to Supabase, last-write-wins with updated_at.
Secrets only server-side; AI via server function. Auth via Supabase.

## Environment limits
Cloud Linux container: logic tested via unit tests, web/Linux builds possible. Windows .exe and signed APK
are built on the user's PC (instructions + script provided).

## Phases
1. Core: map, GPX, profile, weather, analysis wizard.
2. Pack, safety, logbook, account + sync.
3. Specific risks, recording planner, AI assistant.

## Open items for planning
Map tile provider/offline licensing, exact weather API endpoints, Supabase schema, Flutter version check.
