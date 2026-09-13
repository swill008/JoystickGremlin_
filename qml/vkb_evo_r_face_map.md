# VKBsim Gladiator EVO R — Button Map lock

Source of truth for `VkbRigFace.qml` leaders and plus groups.
Photo: `qml/images/vkb_gladiator_rig.jpg`
Device name: `VKBsim Gladiator EVO R` only.
The photo is ONE grip in TWO poses (left = open head, right = closed grip) plus the shared base.

`nx` / `ny` are fractions of the **painted photo**, not the window.
Do not invent new ids. Do not use the yellow F-14 sheet when it conflicts with this file.

## Pose

| Pose | What you see |
|---|---|
| Left | Same EVO R grip twisted open so the head hats are visible |
| Right | Same EVO R grip, white cap and trigger facing the camera |
| Base | Shared base under the shaft |

## Buttons

| HW | Type | Physical | Pose | nx | ny | Group |
|---:|---|---|---|---:|---:|---|
| 1 | button | Red trigger, half pull | Right | 0.665 | 0.385 | pair 1/2 |
| 2 | button | Red trigger, full pull | Right | 0.665 | 0.385 | pair 1/2 |
| 3 | button | Red head button | Left | 0.355 | 0.360 | single |
| 4 | button | White cap | Right | 0.625 | 0.305 | single |
| 5 | button | Lower grip white button (not the base) | Right | 0.640 | 0.520 | single |
| 6 | button | 5-way immediately right of red, up | Left | 0.415 | 0.345 | plus 6-10 |
| 7 | button | that 5-way, right | Left | 0.415 | 0.345 | plus 6-10 |
| 8 | button | that 5-way, down | Left | 0.415 | 0.345 | plus 6-10 |
| 9 | button | that 5-way, left | Left | 0.415 | 0.345 | plus 6-10 |
| 10 | button | that 5-way, center | Left | 0.415 | 0.345 | plus 6-10 |
| 11 | button | Top-right head 5-way, up | Left | 0.470 | 0.275 | plus 11-15 |
| 12 | button | that 5-way, right | Left | 0.470 | 0.275 | plus 11-15 |
| 13 | button | that 5-way, down | Left | 0.470 | 0.275 | plus 11-15 |
| 14 | button | that 5-way, left | Left | 0.470 | 0.275 | plus 11-15 |
| 15 | button | that 5-way, center | Left | 0.470 | 0.275 | plus 11-15 |
| 16 | button | Silver side wheel 5-way, up | Left | 0.400 | 0.470 | plus 16-20 |
| 17 | button | that wheel, right | Left | 0.400 | 0.470 | plus 16-20 |
| 18 | button | that wheel, down | Left | 0.400 | 0.470 | plus 16-20 |
| 19 | button | that wheel, left | Left | 0.400 | 0.470 | plus 16-20 |
| 20 | button | that wheel, center | Left | 0.400 | 0.470 | plus 16-20 |
| 21 | button | Ribbed paddle, push (not the red trigger) | Right | 0.705 | 0.385 | pair 21/22 |
| 22 | button | Ribbed paddle, pull | Right | 0.705 | 0.385 | pair 21/22 |
| 23 | button | En2 right knob, up | Base | 0.720 | 0.820 | pair 23/24 |
| 24 | button | En2 right knob, down | Base | 0.720 | 0.820 | pair 23/24 |
| 25 | button | En1 left knob, up | Base | 0.575 | 0.820 | pair 25/26 |
| 26 | button | En1 left knob, down | Base | 0.575 | 0.820 | pair 25/26 |
| 27 | button | Middle base pad | Base | 0.600 | 0.725 | pads |
| 28 | button | Left base pad | Base | 0.555 | 0.735 | pads |
| 29 | button | Right base pad | Base | 0.645 | 0.715 | pads |

## Hats

| HW | Type | Physical | Pose | nx | ny |
|---:|---|---|---|---:|---:|
| 1 | hat 8-way | Analog ministick on the open head | Left | 0.355 | 0.250 |

6-10, 11-15, 16-20 are **buttons**, not DILL hats.

## Axes

| HW | Type | Physical | Pose | nx | ny |
|---:|---|---|---|---:|---:|
| 1 | axis | Stick X (roll) | Gimbal / shaft | 0.455 | 0.680 |
| 2 | axis | Stick Y (pitch) | Gimbal / shaft | 0.455 | 0.680 |
| 3 | axis | Stick Z twist | Gimbal / shaft | 0.455 | 0.680 |
| 4 | axis | Z slider, between En1 and En2 | Base | 0.635 | 0.820 |

## Plus layout (card structure)

```
        UP
LEFT  CENTER  RIGHT
       DOWN
```

- 6-10: 6 up, 8 down, 9 left, 7 right, 10 center
- 11-15: 11 up, 13 down, 14 left, 12 right, 15 center
- 16-20: 16 up, 18 down, 19 left, 17 right, 20 center

## Window chrome (not photo nx/ny)

Left column: H1, plus 11-15, plus 6-10, 3, plus 16-20, A1-A3
Right column: 4, 21/22, 1/2, 5
Bottom row: 25/26, 28, 27, 29, A4, 23/24

## Do not

- Do not treat the left and right grips as two devices.
- Do not put 1/2 on the left-pose trigger.
- Do not put 21/22 on the red trigger.
- Do not put 5 on the base.
- Do not swap En1/En2 (25/26 left, 23/24 right).
- Do not put A3 on the slider. A3 is twist. A4 is the slider.
