# Design

A sidescroller platformer with some puzzle elements that depend on the player size.

## Puzzles (rough)

- "I want it to be two platforms that are 'connected'. So when the big player
  stands on one of them it sinks, while the other rises."
  - Two platforms are joined by a rope. A pulley wheel sits above each
    platform, and a rope across the top joins the wheels. The ropes lengthen
    and shorten as the platforms move. This is flat placeholder art.
  - When the player is fully big (`t` = 1) and stands on one platform, that
    platform sinks all the way to its bottom stop. The other rises by the same
    amount.
  - The small player doesn't move them. When the big player leaves or shrinks,
    both slide back to level.
  - The platforms carry whoever stands on them. Boxes never go on them.
  - Travel, sink speed and return speed are exports on the pair, so they can be
    set in the Inspector. Travel defaults to three tiles (48 px). The speeds are
    placeholders for the owner to tune.
  - The camera treats the platforms as normal floor.
  - The pair is a scene that the owner places in the editor.
  - The seesaw level becomes a minimal grey-box platforms level, made in the
    editor: the smallest level that shows the mechanic.
- Pushing things.
- Fitting through things.
  - The things are gaps in the tiles: tunnels, low ceilings, narrow shafts.
  - Only the small player fits. Big is blocked.
  - Openings are whole tiles. A 1-tile-tall tunnel is the small-only opening.
    Big needs 2 tiles wide by 3 tall.
  - It applies to the player only. Boxes come later.
  - Growing with no room:
    - Holding Shift where big doesn't fit keeps the player small. There's no
      cue for now.
    - Big must fit exactly where the player stands. The player doesn't slide
      sideways to make room.
    - With Shift still held, the player grows as soon as big fits, for example
      on walking out of a tunnel.
  - Grey-box level:
    - It's a new minimal level made in the editor: a floor and a wall with a
      1-tile-tall tunnel at floor level, with the player starting on one side.
    - The camera behaves normally in the tunnel.
- Timing: the player triggers something while large and uses speed to get
  somewhere before a door closes etc.

## Levels

- "i want to move away from the concept of rooms and just have levels"
  - A level is one continuous space with no rooms or transitions inside it.
  - "main is a level too"

## Look

- A sprite and tile based pixel art game.
- 320×180, 16 px tiles.
- The owner draws the art; flat placeholders until then.

## Player size

- Two states, small and big.
- Big jumps lower.
- 10×16 small, 30×48 big.

## Boxes

- BOX A is 1 tile, BOX B is 2×2 tiles.

## Pushing

- The player can only push one box.

## Camera

- Manual look up and down: Up / Down arrows.

## Grey-box order

- The linked platforms first.
