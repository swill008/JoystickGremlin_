# VKBsim Gladiator EVO R — Button Map lock

Source of truth for `VkbRigFace.qml` leaders and plus groups.
Photo: `qml/images/vkb_gladiator_rig.jpg` (899 x 920).
Device name: `VKBsim Gladiator EVO R` only.
ONE grip, TWO poses (left = open head, right = closed grip) plus the shared base.

`nx` / `ny` = pixel / size on that JPEG. Measured on the bitmap, not a window screenshot.

## Buttons

| HW | Physical | Pose | px | py | nx | ny | Group |
|---:|---|---|---:|---:|---:|---:|---|
| 1 | Red trigger half | Right | 610 | 250 | 0.679 | 0.272 | pair 1/2 |
| 2 | Red trigger full | Right | 610 | 250 | 0.679 | 0.272 | pair 1/2 |
| 3 | Red head button | Left | 311 | 234 | 0.346 | 0.254 | single |
| 4 | White cap | Right | 551 | 227 | 0.613 | 0.247 | single |
| 5 | Lower grip white | Right | 544 | 386 | 0.605 | 0.420 | single |
| 6 | 5-way right of red, up | Left | 372 | 216 | 0.414 | 0.235 | plus 6-10 |
| 7 | that 5-way, right | Left | 372 | 216 | 0.414 | 0.235 | plus 6-10 |
| 8 | that 5-way, down | Left | 372 | 216 | 0.414 | 0.235 | plus 6-10 |
| 9 | that 5-way, left | Left | 372 | 216 | 0.414 | 0.235 | plus 6-10 |
| 10 | that 5-way, center | Left | 372 | 216 | 0.414 | 0.235 | plus 6-10 |
| 11 | Top-right head 5-way, up | Left | 375 | 168 | 0.417 | 0.183 | plus 11-15 |
| 12 | that 5-way, right | Left | 375 | 168 | 0.417 | 0.183 | plus 11-15 |
| 13 | that 5-way, down | Left | 375 | 168 | 0.417 | 0.183 | plus 11-15 |
| 14 | that 5-way, left | Left | 375 | 168 | 0.417 | 0.183 | plus 11-15 |
| 15 | that 5-way, center | Left | 375 | 168 | 0.417 | 0.183 | plus 11-15 |
| 16 | Silver wheel 5-way, up | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 17 | that wheel, right | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 18 | that wheel, down | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 19 | that wheel, left | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 20 | that wheel, center | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 21 | Ribbed paddle push | Right | 632 | 248 | 0.703 | 0.270 | pair 21/22 |
| 22 | Ribbed paddle pull | Right | 632 | 248 | 0.703 | 0.270 | pair 21/22 |
| 23 | En2 right knob up | Base | 638 | 708 | 0.710 | 0.770 | pair 23/24 |
| 24 | En2 right knob down | Base | 638 | 708 | 0.710 | 0.770 | pair 23/24 |
| 25 | En1 left knob up | Base | 558 | 708 | 0.621 | 0.770 | pair 25/26 |
| 26 | En1 left knob down | Base | 558 | 708 | 0.621 | 0.770 | pair 25/26 |
| 27 | Middle base pad | Base | 622 | 630 | 0.692 | 0.685 | pads |
| 28 | Left base pad | Base | 583 | 642 | 0.648 | 0.698 | pads |
| 29 | Right base pad | Base | 658 | 622 | 0.732 | 0.676 | pads |

## Hats

| HW | Physical | px | py | nx | ny |
|---:|---|---:|---:|---:|---:|
| 1 | Analog ministick 8-way | 335 | 168 | 0.373 | 0.183 |

## Axes

| HW | Physical | px | py | nx | ny |
|---:|---|---:|---:|---:|---:|
| 1 | Stick X roll | 386 | 529 | 0.429 | 0.575 |
| 2 | Stick Y pitch | 386 | 529 | 0.429 | 0.575 |
| 3 | Stick Z twist | 386 | 529 | 0.429 | 0.575 |
| 4 | Z slider between En1 and En2 | 590 | 708 | 0.656 | 0.770 |

## Plus layout

- 6-10: 6 up, 8 down, 9 left, 7 right, 10 center
- 11-15: 11 up, 13 down, 14 left, 12 right, 15 center
- 16-20: 16 up, 18 down, 19 left, 17 right, 20 center

## Do not

- Do not measure nx/ny from a window screenshot.
- A3 is twist at the gimbal. A4 is the slider.
- En1 = 25/26. En2 = 23/24.
- Button 3 is the red head button centroid (311,234), not the 5-way to its right.
- Button 4 is the white cap centroid (551,227), not the gray above the grip.
- Button 5 is the lower-grip white centroid (544,386), not the space to its right.
