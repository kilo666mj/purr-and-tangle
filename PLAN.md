# Purr & Tangle game plan

## Concept

A cat-themed falling-pair puzzle game inspired by Dr. Mario. Cats work together
to untangle a giant yarn basket and rescue the kittens hiding inside. Position
pairs of cats to make lines of four matching colors, clear the tangled yarn,
and trigger satisfying chain reactions.

Purr & Tangle is the working title. The concept below captures the initial
direction; board dimensions, difficulty, scoring, and controls are prototype
defaults to refine through playtesting.

## Pieces and setting

| Element | Appearance | Role |
| --- | --- | --- |
| Orange cat | Orange tabby with stripes | One of three matching colors |
| Blue cat | Blue-gray sleepy cat with spots | Second matching color |
| Purple cat | Purple-tinted mischievous cat with zigzags | Third matching color |
| Yarn tangle | Orange, blue, or purple yarn ball with kitten eyes peeking out | Fixed target to clear |
| Falling pair | Two cats holding onto each other | Movable piece, with matching or mixed colors |
| Playfield | Tall wicker basket | Holds the puzzle grid |
| Next-piece preview | Two cats waiting in a cardboard box | Shows the next pair |

Use the same color and pattern on corresponding cats and yarn. Keep their
silhouettes distinct so players can identify both color groups and target types
without relying on color alone. A cat perched on the basket rim drops each pair.

## Core rules

1. Start with an 8-column by 16-row basket containing yarn tangles in its lower
   portion. Leave room for incoming pieces and avoid pre-existing matches.
2. Drop one connected pair of cats from the top. The player can move it left or
   right, rotate it, and speed up its descent.
3. Lock the pair when it lands. A straight horizontal or vertical run of four
   or more cells of one color clears. Cats and yarn both count; diagonals do not.
4. Clear all qualifying runs at once, including intersections. Yarn unravels
   to release its kitten, and matched cats scamper away.
5. Yarn tangles stay fixed until cleared. Unsupported cats fall. Intact pairs
   remain connected and fall together only when both cells can move down; when
   one cat clears, the surviving cat becomes an independent piece.
6. After gravity settles, check for new matches. Repeat until the board is
   stable, then spawn the next pair.
7. Clear every yarn tangle to finish the level. If the next pair cannot spawn,
   the game ends. Resolve a completed level before checking for another spawn.

Increase difficulty with more tangles and faster falling pieces. Award points
for clearing yarn and bonuses for consecutive clear-and-fall reactions; tune
the numbers after the basic game feels good.

## First playable version

- Single-player level progression with three colors.
- Movement, rotation, soft drop, collision handling, and predictable locking.
- Next-pair preview, score, level, and remaining-tangle count.
- Start, pause, resume, restart, level-complete, and game-over screens.
- A short explanation of matching four and clearing all yarn.
- Distinct patterns, readable contrast, mute, and reduced-motion settings.

The initial solo version is now extended with local two-player versus and
difficulty presets (below). Keep online multiplayer, special pieces, power-ups,
accounts, and online leaderboards for later consideration.

## Visual and audio direction

Use a cozy room, warm wicker, and bold, readable pieces. Keep the board visually
quiet enough that players can scan it quickly. Cats can blink while waiting,
cling together while falling, dangle after a match, and look offended when
rotated. Clearing yarn should feel like rescuing a kitten.

Start with simple placeholder shapes. Once the rules work, add three cat
designs, three yarn designs, the basket, the preview box, and short animations
for falling, locking, clearing, and celebrating. Use original artwork and sound.
Soft landing taps, yarn pops, and occasional purrs should support play without
becoming repetitive.

## Implementation milestones

### 1. Choose the platform and build the rules

- [x] Choose the initial platform and engine before scaffolding the project.
- [x] Model the grid, fixed yarn, cat colors, and connections between paired cats.
- [x] Implement spawning, movement, rotation, collision, and locking.
- [x] Implement simultaneous matches, pair splitting, gravity, and chain reactions.
- [x] Support reproducible puzzle layouts and piece sequences for debugging.

### 2. Make a complete playable loop

- [x] Render a playable board with placeholder art and the next-pair preview.
- [x] Add the controls appropriate to the chosen platform.
- [x] Add scoring, level generation, progression, victory, and game over.
- [x] Add pause, restart, and a brief first-play explanation.

### 3. Give the game its cat personality

- [x] Replace placeholders with the cats, yarn, wicker basket, and cardboard box.
- [ ] Add clear, gravity, rescue, and celebration animations.
- [x] Add sound, mute, reduced motion, and persistent visual pattern cues.
- [x] Adjust layout and controls for each supported screen size and input type.

The first pass includes smooth piece/gravity movement, clear pulses, and rescue
hearts. Dedicated character and celebration animations remain a polish step.
Desktop resizing and keyboard/controller/clickable controls are implemented;
mobile layout and touch-first play are outside the initial desktop target.

### 4. Validate and tune

- [x] Test horizontal, vertical, intersecting, and longer-than-four matches.
- [x] Test disconnected cats, intact pairs, fixed yarn, and multi-step chains.
- [x] Test rotation at walls and obstacles, blocked spawning, and clearing the
      final tangle near the top of the board.
- [x] Verify pause freezes both falling pieces and any pending resolution.
- [ ] Playtest pacing, input responsiveness, readability, and difficulty.

The first version is ready when a player can learn the rule, finish a level,
continue to another, lose, and restart without broken piece connections or
unresolved board states.

## Initial implementation choices

- Desktop first, Godot 4.7.2 with GDScript and the compatibility renderer.
- Clay-style artwork with six textured GLB models rendered to sprites in
  Blender. The game uses those renders; editable models and source artwork
  are included.
- Keyboard, controller (D-pad/left stick and face buttons), and clickable controls.
- Individual runs with persistent accessibility preferences and best score.
- Seeded layouts and piece sequences; default run seed 1729.
- See README.md for running, testing, controls, and the art pipeline.

Automated coverage includes randomized bond/settling invariants and injected
gamepad events, including menu selection. Physical controller feel, sound,
difficulty pacing, and extended playtesting remain to be evaluated on a desktop.

## Local versus and difficulty

- [x] Two independent baskets with equal seeded layouts and pair sequences.
- [x] Controller join lobby with separate device ownership, mixed keyboard/pad,
      and shared-keyboard controls.
- [x] Shared countdown/pause, disconnect recovery, race outcomes, ties, win tally,
      and progressively faster rematches.
- [x] Shared basket rendering, next-pair previews, scores and rescue counts.
- [x] Relaxed, Normal and Spicy presets with saved selection; versus uses one
      shared preset per match.
- [x] Faster starting pace between baskets and a 15% shorter fall interval every
      20 seconds during a basket, capped at 180 ms. Visible speed/countdown
      indicator; pauses freeze the timer and versus uses one shared clock.
- [x] Automated fairness, device isolation, difficulty, reconnect, rematch and
      single-player regression checks; actual rendered screenshots inspected.
- [x] Use the orange cat artwork as the application/window icon.

This mode is a local race to clear all yarn or outlast the opponent's full
basket. Garbage attacks and network play remain outside this implementation.
See README.md for the exact difficulty values and player controls.

## Mini-game collection

Purr & Tangle is growing into a small collection of original cat games in
classic arcade genres, chosen from the title screen. They share the cats, yarn,
menus, sound and input handling; each game adds only its own rules and screen.
Borrow a genre's mechanics, never a specific game's characters, levels or look.
Do not build a shared mini-game framework until a third game shows what is
worth sharing.

- [x] **Yarn trail** (snake-style): a kitten gathers yarn balls and drags an
      ever-longer strand around the basket without crossing it or leaving.

Ideas for later:

- [ ] **Laser pounce** (reaction): a red dot darts around and you pounce on it
      before it moves. Would suit two-player versus.
- [ ] **Shelf swat** (paddle and ball): bat a yarn ball upward to knock things
      off shelves.
- [ ] **Kitchen dash** (lane crossing): get a kitten across a busy kitchen
      floor past robot vacuums and rolling yarn.
- [ ] **Treat maze** (maze chase): collect treats while the tangles chase you.
- [ ] **Kitten match** (memory): flip cards to pair up kittens.

Yarn trail keeps its own best score. It has no difficulty presets, versus mode
or settings in its pause menu yet (M still mutes).
