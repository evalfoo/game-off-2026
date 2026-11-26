# Coding standards

Apply these review rules when the change touches the behavior below. Use judgment about which cases apply to the feature. Add a rule when review keeps catching the same class of bug.

## Randomness

Draw gameplay randomness from a `RandomNumberGenerator` whose seed the game or fixture sets, never from the global `randf()` and `randi()`. A seeded run with `--fixed-fps` must replay the same, so checks, clips and agent playtests compare like with like before and after a change.

## Numbers shown to the player

Get displayed gameplay numbers from the same function the simulation uses. Include discounts, caps and slowdowns in the value shown. Check tooltips and explanatory text against the effective result.
