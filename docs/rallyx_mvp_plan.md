# Rally-X Inspired Game - MVP Plan

Last updated: 2026-03-09

## 1. Product Goal

Build a modern implementation of Rally-X using Flutter + Flame + Forge2D for desktop (Windows/macOS), with:

- continuous (non-grid-locked) car movement,
- semi-arcade driving feel,
- procedural maze level generation,
- survival-time-focused gameplay.

## 2. Confirmed Scope

- Mode: single-player.
- View: top-down with smooth follow camera.
- Art: retro pixel placeholders for MVP.
- Input: keyboard only in MVP.
- Physics: semi-arcade, simple handling (no gears).
- Level: one procedural level format, generated each run, with baseline size and responsive upscaling on larger viewports.
- Objective: stay alive; flags grant time-score bonuses.
- Lose conditions:
  - fuel empty,
  - one enemy hit.
- Enemy theme: Tesla Robo-Taxis.
- Player car theme: Ioniq 5.
- Persistence: keep best 10 high scores in SharedPreferences.
- Tests: simple unit tests.
- Target frame rate: 60 FPS.

## 3. Rally-X Parity Decisions for MVP

- Map scale uses Rally-X-inspired proportions at a larger modern baseline:
  - baseline playfield grid: 175x97 tiles,
  - baseline world width budgeting includes an 8-tile HUD strip concept,
  - visible camera target is roughly 24x24 tiles and scales with viewport size.
- Keep fuel as timer/resource.
- Keep smoke mechanic.
- Keep static map hazards only (no moving obstacles).
- Keep single special flag behavior (no Lucky Flag for MVP).
- Stage progression exists and difficulty ramps per level.
- Stage clear refills fuel to full.

## 4. Gameplay Loop (MVP)

1. Spawn in generated maze.
2. Drive and avoid enemy Robo-Taxis.
3. Collect flags for bonus time-score.
4. Use smoke to temporarily disable enemies (costs fuel).
5. Clear all flags to advance stage (difficulty increases).
6. Survive as long as possible.
7. Run ends on collision or fuel depletion.
8. Save score to top-10 leaderboard.

## 5. Architecture Overview

### 5.1 Tech Stack

- Flutter app shell
- Flame game loop/components
- Forge2D physics world
- SharedPreferences persistence

### 5.2 Core Modules

- `input/`: abstract command interface + keyboard implementation.
- `entities/`: cars, flags, walls, rocks, smoke.
- movement/chase controller logic: implemented within entity components for MVP (`PlayerCarComponent`, `EnemyCarComponent`).
- `level/`: procedural map generation + future level-provider abstraction.
- runtime systems: fuel, scoring, stage progression, and enemy spawning are orchestrated in `RallyXGame` for MVP.
- `ui/`: HUD, minimap, overlays.
- `persistence/`: high score repository.

### 5.3 Input Contract

Polled every frame and analog-friendly:

- `throttle` in `[0..1]`
- `brake` in `[0..1]`
- `steering` in `[-1..1]`
- `smoke` as boolean action

Keyboard implementation translates keys to this command object.
Game logic reads only commands, never keyboard directly.

## 6. Physics and Controls

- Fixed-step simulation at 60 Hz.
- Player car:
  - throttle accelerates forward,
  - brake slows down and enables reverse at low speed,
  - steering controls heading,
  - simple lateral damping for controllable semi-arcade handling.
- Collision with walls should slide, not bounce hard.
- Enemy cars use simpler version of same movement model.

## 7. Level and Navigation

### 7.1 Level Provider Abstraction

Introduce now for future extensibility:

- `LevelProvider` interface
- `ProceduralLevelProvider` for MVP
- future `JsonLevelProvider` for hand-authored levels

### 7.2 Procedural Rules

- Generate connected tile-aligned corridor maze in the active procedural grid dimensions (baseline 175x97, with responsive upscaling).
- Generate a new run seed each restart; keep that seed across stage progression.
- Build static colliders for walls and rocks.
- Place player spawn, enemy spawns, and 10 flags.
- Guarantee flag reachability from player spawn.

### 7.3 Enemy Pursuit

- Physics-like pursuit with simple chase.
- Path guidance from corridor graph waypoints.
- No enemy-to-enemy interaction mechanics.
- Smoke applies temporary stun state.

## 8. UI and Debug

MVP HUD:

- fuel,
- survival time,
- minimap (full map visible).

Debug overlay (toggle):

- FPS,
- current seed,
- player speed,
- fuel value,
- stage,
- enemy count.

## 9. Persistence

- Save top 10 scores in SharedPreferences.
- Score basis: survival time (+ flag bonus contribution).
- Keep sorted leaderboard and trim to 10 entries.

## 10. Milestones (Summary)

1. M0: Bootstrap Flame/Forge2D project and 60 FPS loop.
2. M1: Input abstraction + player car movement.
3. M2: Procedural level generation + static colliders.
4. M3: Fuel/smoke/flags/score/stage systems.
5. M4: Enemy Robo-Taxis and collision game-over.
6. M5: HUD + full minimap + smooth camera polish.
7. M6: High-score persistence + game-over/restart flow.
8. M7: Unit tests + balancing + bugfix pass.

## 11. Milestone Task Board

Status legend:

- [ ] Not started
- [x] Completed

### M0 - Bootstrap

- [x] Create Flutter desktop project with Windows and macOS enabled.
- [x] Add dependencies: `flame`, `flame_forge2d`, `shared_preferences`.
- [x] Implement base `RallyXGame` using `Forge2DGame`.
- [x] Set up fixed-step simulation targeting 60 Hz.
- [x] Add placeholder camera and empty world scene.
- [x] Add debug overlay toggle scaffold.
- [ ] Exit criteria: app runs on Windows/macOS and game loop is stable.
  - Validation note (2026-03-07): `flutter build macos` succeeded; Windows runtime check pending.

### M1 - Input + Player Driving

- [x] Add `VehicleCommand` model (`throttle`, `brake`, `steering`, `smoke`).
- [x] Add `InputSource` interface with frame polling.
- [x] Implement `KeyboardInputSource`.
- [x] Implement `PlayerCarComponent` with semi-arcade movement.
- [x] Implement reverse-at-low-speed behavior.
- [x] Tune wall collision to slide rather than bounce.
- [ ] Exit criteria: arrow keys + smoke control drive the car correctly.
  - Validation note (2026-03-07): input mapping tests pass; manual driving verification pending.

### M2 - Procedural Level

- [x] Add `LevelProvider` abstraction and `ProceduralLevelProvider`.
- [x] Generate connected 32x32 maze with tile-aligned corridors.
- [x] Build static wall and rock colliders from generated map.
- [x] Add spawn placement for player, enemies, and flags.
- [x] Place exactly 10 flags including one special flag.
- [x] Validate reachability from player spawn to all flags.
- [ ] Exit criteria: every run creates a valid playable level.
  - Validation note (2026-03-07): generator validity tests pass and macOS build succeeds; in-game repeated-run playtest still pending.

### M3 - Core Gameplay Systems

- [x] Implement `FuelSystem` with passive fuel drain.
- [x] Implement smoke action and fuel consumption.
- [x] Implement smoke cloud and enemy stun timing.
- [x] Implement `ScoringSystem` (survival time + flag bonus).
- [x] Implement stage clear condition when all flags are collected.
- [x] Refill fuel to full at stage transition.
- [ ] Exit criteria: complete Rally-X-like survival loop works without enemies.
  - Validation note (2026-03-07): fuel/smoke/flag/stage loop is implemented and builds/tests pass; gameplay tuning playtest still pending.

### M4 - Enemies (Tesla Robo-Taxis)

- [x] Implement `EnemyCarComponent`.
- [x] Implement simple physics-like chase controller.
- [x] Add corridor-graph waypoint guidance.
- [x] Apply smoke stun effect to enemies.
- [x] Implement one-hit collision game-over.
- [x] Add per-stage difficulty scaling (count/speed/tuning).
- [ ] Exit criteria: enemies chase reliably and create survival pressure.
  - Validation note (2026-03-07): chase/smoke/collision systems implemented with stage scaling; gameplay balance playtest still pending.

### M5 - HUD, Minimap, Camera Polish

- [x] Implement HUD for fuel, survival time, and stage.
- [x] Implement full-map minimap panel.
- [x] Add minimap markers for player, enemies, and flags.
- [x] Tune smooth-follow camera and clamp to map bounds.
- [x] Add clear game-over overlay and restart action.
- [ ] Exit criteria: gameplay information is always visible and readable.
  - Validation note (2026-03-07): HUD/minimap/game-over overlays implemented and build/tests pass; readability tuning playtest pending.

### M6 - Persistence + Run Loop Finalization

- [x] Implement `HighScoreRepository` with SharedPreferences.
- [x] Persist and load top 10 scores.
- [x] Sort descending and trim leaderboard to 10.
- [x] Connect score submission on game-over.
- [x] Ensure restart resets runtime state cleanly.
- [x] Exit criteria: scores persist across app restarts.
  - Validation note (2026-03-07): persistence tests cover cross-instance reload and top-10 storage behavior.

### M7 - Tests, Debug, Tuning

- [x] Add debug metrics: FPS, seed, speed, fuel, stage, enemy count.
- [x] Add unit tests for input mapping.
- [x] Add unit tests for generation reachability.
- [x] Add unit tests for scoring and leaderboard logic.
- [x] Perform balancing pass for fuel drain, enemy speed, and smoke duration.
- [x] Run regression pass on stage transitions and game-over paths.
- [ ] Exit criteria: tests pass and MVP gameplay feels stable.
  - Validation note (2026-03-07): full test suite passes including runtime regression (restart, stage advance, enemy scaling/override) and generation stress tests; final manual gameplay feel pass still pending.

## 12. Definition of Done (MVP)

- Playable desktop game on macOS/Windows.
- Continuous driving in generated maze with Rally-X-like loop.
- Fuel + smoke + flags + enemies + stage progression functioning.
- Correct lose conditions and survival-time score.
- HUD and minimap operational.
- Top-10 highscores persisted.
- Core unit tests passing.
