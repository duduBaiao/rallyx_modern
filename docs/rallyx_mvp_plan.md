# Rally-X Inspired Game - MVP Plan

Last updated: 2026-03-07

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
- Level: one fixed-size level format, procedurally generated each run.
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

- Map scale follows original Rally-X proportions:
  - world grid: 32x32 tiles,
  - visible playfield area roughly 28x28 tiles,
  - side HUD/radar strip roughly 8x28 tiles.
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
- `controllers/`: player movement and enemy chase behavior.
- `level/`: procedural map generation + future level-provider abstraction.
- `systems/`: fuel, scoring, stage progression, enemy spawning/director.
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

- Generate connected tile-aligned corridor maze in 32x32 grid.
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

- [ ] Add `VehicleCommand` model (`throttle`, `brake`, `steering`, `smoke`).
- [ ] Add `InputSource` interface with frame polling.
- [ ] Implement `KeyboardInputSource`.
- [ ] Implement `PlayerCarComponent` with semi-arcade movement.
- [ ] Implement reverse-at-low-speed behavior.
- [ ] Tune wall collision to slide rather than bounce.
- [ ] Exit criteria: arrow keys + smoke control drive the car correctly.

### M2 - Procedural Level

- [ ] Add `LevelProvider` abstraction and `ProceduralLevelProvider`.
- [ ] Generate connected 32x32 maze with tile-aligned corridors.
- [ ] Build static wall and rock colliders from generated map.
- [ ] Add spawn placement for player, enemies, and flags.
- [ ] Place exactly 10 flags including one special flag.
- [ ] Validate reachability from player spawn to all flags.
- [ ] Exit criteria: every run creates a valid playable level.

### M3 - Core Gameplay Systems

- [ ] Implement `FuelSystem` with passive fuel drain.
- [ ] Implement smoke action and fuel consumption.
- [ ] Implement smoke cloud and enemy stun timing.
- [ ] Implement `ScoringSystem` (survival time + flag bonus).
- [ ] Implement stage clear condition when all flags are collected.
- [ ] Refill fuel to full at stage transition.
- [ ] Exit criteria: complete Rally-X-like survival loop works without enemies.

### M4 - Enemies (Tesla Robo-Taxis)

- [ ] Implement `EnemyCarComponent`.
- [ ] Implement simple physics-like chase controller.
- [ ] Add corridor-graph waypoint guidance.
- [ ] Apply smoke stun effect to enemies.
- [ ] Implement one-hit collision game-over.
- [ ] Add per-stage difficulty scaling (count/speed/tuning).
- [ ] Exit criteria: enemies chase reliably and create survival pressure.

### M5 - HUD, Minimap, Camera Polish

- [ ] Implement HUD for fuel, survival time, and stage.
- [ ] Implement full-map minimap panel.
- [ ] Add minimap markers for player, enemies, and flags.
- [ ] Tune smooth-follow camera and clamp to map bounds.
- [ ] Add clear game-over overlay and restart action.
- [ ] Exit criteria: gameplay information is always visible and readable.

### M6 - Persistence + Run Loop Finalization

- [ ] Implement `HighScoreRepository` with SharedPreferences.
- [ ] Persist and load top 10 scores.
- [ ] Sort descending and trim leaderboard to 10.
- [ ] Connect score submission on game-over.
- [ ] Ensure restart resets runtime state cleanly.
- [ ] Exit criteria: scores persist across app restarts.

### M7 - Tests, Debug, Tuning

- [ ] Add debug metrics: FPS, seed, speed, fuel, stage, enemy count.
- [ ] Add unit tests for input mapping.
- [ ] Add unit tests for generation reachability.
- [ ] Add unit tests for scoring and leaderboard logic.
- [ ] Perform balancing pass for fuel drain, enemy speed, and smoke duration.
- [ ] Run regression pass on stage transitions and game-over paths.
- [ ] Exit criteria: tests pass and MVP gameplay feels stable.

## 12. Definition of Done (MVP)

- Playable desktop game on macOS/Windows.
- Continuous driving in generated maze with Rally-X-like loop.
- Fuel + smoke + flags + enemies + stage progression functioning.
- Correct lose conditions and survival-time score.
- HUD and minimap operational.
- Top-10 highscores persisted.
- Core unit tests passing.
