# VKBsim Gladiator EVO R — Button Map lock

Live runtime for chips, hotspots, spines, and image:
`qml/maps/vkb_evo_r.json` (`control.hardware`). Save in the Button Map editor is truth.

This file is the measured JPEG inventory and the hardware-id lock.
Photo: `qml/images/vkb_gladiator_rig.jpg` (899 x 920).
Device name: `VKBsim Gladiator EVO R` only.
ONE grip, TWO poses (left = open head, right = closed grip) plus the shared base.

`nx` / `ny` = pixel / size on that JPEG. Measured on the bitmap, not a window screenshot.

## Buttons

| HW | Physical | Pose | px | py | nx | ny | Group |
|---:|---|---|---:|---:|---:|---:|---|
| 1 | Red trigger half | Right | 555 | 277 | 0.617 | 0.301 | pair 1/2 |
| 2 | Red trigger full | Right | 555 | 277 | 0.617 | 0.301 | pair 1/2 |
| 3 | Red head button | Left | 311 | 234 | 0.346 | 0.254 | single |
| 4 | White cap | Right | 551 | 227 | 0.613 | 0.247 | single |
| 5 | Lower grip white | Right | 544 | 386 | 0.605 | 0.420 | single |
| 6 | 5-way right of red, up | Left | 370 | 210 | 0.412 | 0.228 | plus 6-10 |
| 7 | that 5-way, right | Left | 370 | 210 | 0.412 | 0.228 | plus 6-10 |
| 8 | that 5-way, down | Left | 370 | 210 | 0.412 | 0.228 | plus 6-10 |
| 9 | that 5-way, left | Left | 370 | 210 | 0.412 | 0.228 | plus 6-10 |
| 10 | that 5-way, center | Left | 370 | 210 | 0.412 | 0.228 | plus 6-10 |
| 11 | Top-right head 5-way, up | Left | 376 | 161 | 0.418 | 0.175 | plus 11-15 |
| 12 | that 5-way, right | Left | 376 | 161 | 0.418 | 0.175 | plus 11-15 |
| 13 | that 5-way, down | Left | 376 | 161 | 0.418 | 0.175 | plus 11-15 |
| 14 | that 5-way, left | Left | 376 | 161 | 0.418 | 0.175 | plus 11-15 |
| 15 | that 5-way, center | Left | 376 | 161 | 0.418 | 0.175 | plus 11-15 |
| 16 | Silver wheel 5-way, up | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 17 | that wheel, right | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 18 | that wheel, down | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 19 | that wheel, left | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 20 | that wheel, center | Left | 360 | 340 | 0.400 | 0.370 | plus 16-20 |
| 21 | Grey upper paddle / flipper push | Right | 590 | 258 | 0.656 | 0.280 | pair 21/22 |
| 22 | Grey upper paddle / flipper pull | Right | 590 | 258 | 0.656 | 0.280 | pair 21/22 |
| 23 | En2 right knob up | Base | 664 | 734 | 0.739 | 0.798 | pair 23/24 |
| 24 | En2 right knob down | Base | 664 | 734 | 0.739 | 0.798 | pair 23/24 |
| 25 | En1 left knob up | Base | 560 | 734 | 0.623 | 0.798 | pair 25/26 |
| 26 | En1 left knob down | Base | 560 | 734 | 0.623 | 0.798 | pair 25/26 |
| 27 | Middle base pad | Base | 558 | 652 | 0.621 | 0.709 | pads |
| 28 | Left base pad | Base | 516 | 654 | 0.574 | 0.711 | pads |
| 29 | Right base pad | Base | 588 | 644 | 0.654 | 0.700 | pads |

## Hats

| HW | Physical | px | py | nx | ny |
|---:|---|---:|---:|---:|---:|
| 1 | Analog ministick 8-way | 310 | 166 | 0.345 | 0.180 |

## Axes

| HW | Physical | px | py | nx | ny |
|---:|---|---:|---:|---:|---:|
| 1 | Stick X roll | 386 | 529 | 0.429 | 0.575 |
| 2 | Stick Y pitch | 386 | 529 | 0.429 | 0.575 |
| 3 | Stick Z twist | 386 | 529 | 0.429 | 0.575 |
| 4 | Z slider between En1 and En2 | 598 | 734 | 0.665 | 0.798 |

## Plus layout

- 6-10: 6 up, 8 down, 9 left, 7 right, 10 center
- 11-15: 11 up, 13 down, 14 left, 12 right, 15 center
- 16-20: 16 up, 18 down, 19 left, 17 right, 20 center

## Chip zones

Stock JSON seed only (`qml/maps/vkb_evo_r.json`). Live layout is whatever Save last wrote.
Do not use this section to change nx/ny.

Chips hug the photo and sit at hotspot Y so leaders stay near-horizontal. 5-ways stay plus groups (do not split).
- Left, top to bottom by target Y (no cross): H1, 11-15, 6-10, 3. Then 16-20 at the wheel. A1-A3 at the gimbal.
- Right, top to bottom: 4, 21/22, 1/2 at the closed grip. 5 at the lower white.
- Bottom, left to right: 28, 27, 29, 25/26, A4, 23/24.

## Do not

- Do not measure nx/ny from a window screenshot.
- A3 is twist at the gimbal. A4 is the slider.
- En1 = 25/26. En2 = 23/24.
- Button 3 is the red head button centroid (311,234), not the 5-way to its right.
- Button 4 is the white cap centroid (551,227), not the gray above the grip.
- Button 5 is the lower-grip white centroid (544,386), not the space to its right.
- 21/22 is the grey flipper face right of the red trigger (590,258). Not the red trigger. Not past the flipper tip in the background.
- 1/2 is the right-grip red trigger centroid (555,277).
- H1 is the analog ministick nub (310,166), not the right rim of the well.
- 11-15 is the top-right 5-way center hole (376,161).
- 6-10 is the lower 5-way center (370,210), right of the red.
- 28 = far-left square (516,654). 27 = middle square (558,652). 29 = right square (588,644). Do not pile them on the right pad.
- 25/26 En1 knob center (560,734), not the top rim. 23/24 En2 knob center (664,734), not the left rim. A4 slider center (598,734), not the top rim.
