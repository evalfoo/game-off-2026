# Design

A sidescroller platformer with some puzzle elements that depend on the player size.

## Puzzles (rough)

- Using your weight to push down a seesaw.
- Pushing things.
- Fitting through things.
- Timing: the player triggers something while large and uses speed to get
  somewhere before a door closes etc.

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

- The seesaw first.

## Open

- The seesaw room's WEIGHT: a loose box or fixed to the plank.
