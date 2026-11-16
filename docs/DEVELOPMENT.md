# Development guide

[Back to the game overview](../README.md)

## Running from source

Open `project.godot` in Godot 4.7.2 and press F5, or run:

```sh
git clone https://github.com/kilo666mj/purr-and-tangle.git
cd purr-and-tangle
bash scripts/install_godot.sh
bash scripts/run.sh
```

The portable Linux engine can be downloaded into the ignored `.tools/` folder
with `bash scripts/install_godot.sh`. Set `GODOT_BIN` to use another installation.
The first version targets desktop, with a resizable window, keyboard, controller,
and clickable on-screen controls. The game starts maximized with normal window
controls; restoring it gives a 990×810 window. The orange cat is the
application/window icon. An original cat-and-yarn splash replaces the Godot
startup logo without adding a forced loading delay.
Settings, difficulty selection, and the best solo score persist locally;
individual runs and versus win tallies start fresh when the game closes.

All artwork and model renders are included. Playing requires no API keys or
external services. Blender is optional for rendering the included 3D models.

| Action | Keyboard | Controller (standard layout) |
| --- | --- | --- |
| Move | Left/right arrows or A/D | D-pad or left stick |
| Rotate clockwise | Up, W or X | A / south button |
| Rotate counterclockwise | Z | B / east button |
| Soft drop | Down or S | D-pad/stick down |
| Hard drop | Space | X / west button |
| Pause/resume | Esc or P | Start |
| Menu navigation | Arrow keys | D-pad |
| Menu selection | Enter | A / south button |
| Mute | M or pause menu | Pause menu |

Pause also freezes pending chain reactions. Losing window focus or disconnecting
a controller pauses play. The pause menu provides mute, reduced motion, pattern
cues, and restart. Stripes, spots, and zigzags identify the three colors without
depending on color alone. Darker markings on a piece are decorative: each cat
and each yarn ball has exactly one matching color. Falling pairs may contain
two different colors.

Textured wool loops connect bonded cats near their paws in the basket and
next-pair previews. The
left-side companion breathes gently, bounces when a pair lands, celebrates
clears and rescues, and looks worried when settled pieces reach the top four
rows. Pausing freezes these reactions; reduced motion keeps the artwork and
cues but disables movement. Solo and versus results show a cat tossing yarn
for a win and a cat tangled in yarn for a loss.

## Local two-player versus

Choose **Local two-player versus** on the puzzle's start screen. Press A on each of two
different controllers to join; press Start or select **Start the race** when
both players are ready. Controller assignments stay fixed for the match, and
a third controller cannot interfere. B releases a controller's slot in the lobby.

Two controllers, keyboard plus controller, and a shared keyboard are supported.
Choose keyboard slots with the lobby buttons or F1 (P1) / F2 (P2):

| Action | Player 1 keyboard | Player 2 keyboard | Each controller |
| --- | --- | --- | --- |
| Move | A / D | Left / right | D-pad or left stick |
| Rotate clockwise | W | Up | A |
| Rotate counterclockwise | Q | Comma | B |
| Soft drop | S | Down | D-pad/stick down |
| Hard drop | E | Period | X |
| Pause | Esc / P | Esc / P | Start |

Both players receive identical yarn layouts and the same sequence of pairs,
even if one drops faster. A three-second countdown starts each round. Clear all
your yarn first, or win when the other basket fills up. Simultaneous clears or
simultaneous losses are a draw. Rematches retain wins and controller assignments
and advance both players to the next, faster basket. This is a local race mode;
online play and attacks that send pieces to the other basket are not implemented.

Pausing, losing window focus, or disconnecting an assigned controller freezes
both baskets, including countdowns and chains. Press A on a replacement
controller, or choose the missing player's keyboard, before resuming. Returning
to the main menu ends the match; versus progress is not saved.

Solo progress is saved at the start of each basket (`begin_basket` in
`main.gd`): the basket number and the score carried into it. Losing keeps it;
only **Start fresh** resets it. The board itself is never saved.

## Difficulty and speed

Select a difficulty on the puzzle's start screen or in the versus lobby. It is remembered
locally. Both versus players always share the same preset, and it stays fixed
through level progression and rematches.

| Preset | Starting yarn | Starting fall interval |
| --- | --- | --- |
| Relaxed | 4 | 1.05 seconds per row |
| Normal | 8 | 0.85 seconds per row |
| Spicy | 12 | 0.65 seconds per row |

Every 20 seconds of active play, the natural fall interval becomes 15% shorter,
down to a 180 ms minimum. On Normal, that is 850 ms initially, 723 ms after
20 seconds, 614 ms after 40 seconds, and 522 ms after a minute. The **SPEED**
indicator shows the current rate relative to the basket's starting pace, counts
down to the next increase, and displays **MAX** at the cap.

The timer includes clearing and chain reactions, but stops for pauses, menus,
and the opening countdown. Versus uses one shared timer so both players speed
up together, regardless of how quickly either player drops or clears pieces.

Each new basket adds two yarn tangles (up to 52), shortens the starting fall
interval by 45 ms, and restarts the 20-second timer. Soft drop stays at 55 ms
per row on every preset. Matching, rotations, and lock delay are identical.

## Rules and reproducibility

The board is 8×16. Intact pairs fall together only when both halves can move;
when one half clears, the other becomes independent. Matches clear
simultaneously, followed by gravity and additional matches. Victory is checked
before trying to spawn another pair. Each landing has a 350 ms lock delay.

The default run seed is 1729. Use another reproducible run with:

```sh
bash scripts/run.sh -- --seed=12345
```

`scripts/board.gd` contains the deterministic rules, `session.gd` handles timing
and pause, and `difficulty.gd` defines the presets. `controls.gd` maps solo inputs;
`versus_input.gd` routes each player's devices and `versus_match.gd` manages fair
rounds and outcomes. `main.gd` and `versus_screen.gd` present the modes using a
shared `board_view.gd` and `puzzle_art.gd`. Scoring is 100 per yarn and 20 per cat,
multiplied by chain depth; soft and hard drops add 1 and 2 points per row.

The opening game menu (`show_games` in `main.gd`) shows one card per game, using
`assets/ui/game_<name>.png`. The side games are hosted by `main.gd` and share `side_screen.gd` for their
header, steering, pause and result menus. Each adds a deterministic rules script
and a small screen that draws its board.

- Yarn trail (`trail.gd`, `trail_screen.gd`): each yarn ball scores 10 and
  shortens the step interval by 3 ms, from 170 ms down to 80 ms.
- Laser pounce (`pounce.gd`, `pounce_screen.gd`): the dot allows 0.6 s plus
  320 ms per cell of distance, falling 6 ms per pounce to 140 ms. A pounce
  scores 10 to 20 depending on the time left.
- Kitchen dash (`dash.gd`, `dash_screen.gd`): six lanes step every 300 to
  550 ms, 7% faster per crossing down to 45%. A crossing scores 50. Hazards and
  the kitten are drawn gliding between cells unless motion is reduced.
- Kitten match (`match.gd`, `match_screen.gd`): 24 cards, 20 per pair, and 10
  per unused miss on a win. A mismatch shows for 0.9 s.
- Treat maze (`maze.gd`, `maze_screen.gd`): the kitten steps every 150 ms and
  the tangles every 260 ms, 20 ms faster per maze down to 150 ms. A treat
  scores 10 and a cleared maze 100.
- Shelf swat (`swat.gd`, `swat_screen.gd`): the ball moves 6.5 cells per
  second, rising with each item and room to 12. An item scores 10 and a cleared
  room 100.

To add a side game, write its rules and screen, add a line to `SIDES` in
`main.gd`, and add `assets/ui/game_<key>.png` for its card.

## Artwork and rendering

Six transparent source images live in `assets/sprites/`, with textured GLB
models in `assets/models/` and their rendered sprites in `assets/renders/`.
`assets/provenance.json` lists the asset files and checksums.

The startup illustration, result-screen cats and wool texture live in
`assets/ui/`. Godot's boot splash settings in `project.godot` scale the startup
illustration to fit while preserving its aspect ratio.

Blender renders those models into `assets/renders/`, which the game prefers over
the source artwork. Rebuild them with:

```sh
bash scripts/render_all.sh
```

This uses at most two Blender processes and a project-local sRGB color profile
for reproducible colors. No system Blender configuration is changed.

## Validation

```sh
bash scripts/check.sh
bash scripts/preview.sh all
```

The first command imports resources, checks scripts, exercises deterministic
rules, difficulty presets, isolated inputs, reconnects, rematches and controller
menus headlessly, and tests release packaging. The second uses Xvfb/software
OpenGL to save actual screenshots of solo play, title, versus play, lobby and
pause, every side game, plus solo and versus results under `artifacts/`. Omit `all` for solo
only, pass `versus` for the three versus screens, `outcomes` for the three
result screens, a side game's key such as `trail` or `maze`, or `games` for the opening menu. Desktop display access is required for capture.
Use `bash scripts/preview.sh yarn` to inspect horizontal and vertical yarn
connections alongside the versus previews.
Input tests inject controller events; physical controller feel and sound still
need playtesting on the target desktop.

## Desktop releases

`export_presets.cfg` defines Windows x64, Linux x64, and universal macOS
exports. Install the matching Godot 4.7.2 export templates, then build on the
target operating system:

```sh
python scripts/export_game.py --platform linux --version v0.1.0 --godot godot
# Use --platform windows or --platform macos on those systems.
```

The builder exports the game, launches that packaged executable headlessly
outside the source directory, and produces a ZIP plus SHA-256 checksum in
`dist/`. On macOS it produces a disk image (`.dmg`) instead, holding the app
beside an Applications shortcut for drag-and-drop installing; the build mounts
the image and re-checks its contents and signature. It preserves executable permissions and includes the game license,
instructions, source revision and Godot's bundled third-party license notices.
Source models, reference sprites, tests and screenshots are excluded from the
playable package; the source repository retains them.

The **Desktop release** Actions workflow builds on all three native runners.
Dispatch it with an unused `vMAJOR.MINOR.PATCH` version. After tests and all
exports pass, it creates the tag, uploads the three downloads plus `SHA256SUMS`,
checks GitHub's uploaded asset digests, then publishes the release. Pushing a
new version tag also triggers it. Existing tags/releases are never overwritten.

macOS uses ad-hoc signing and a universal Intel/Apple Silicon
binary. Apple notarization and Windows Authenticode signing are not configured.
See [PLAYING.txt](../PLAYING.txt) for installation details.

## Repository checks

CI runs the Godot checks and Python tests. CodeQL scans Python and Actions
workflows; GDScript is not a CodeQL language. Dependency review runs on pull
requests, and Dependabot maintains Actions pins weekly. See
[SECURITY.md](../SECURITY.md) for reporting vulnerabilities.

