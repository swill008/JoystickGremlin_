# VKBsim Gladiator EVO R — Button Map lock

Source of truth for `VkbRigFace.qml` leaders and plus groups.
Photo: `qml/images/vkb_gladiator_rig.jpg` (899 x 920).
Device name: `VKBsim Gladiator EVO R` only.
ONE grip, TWO poses (left = open head, right = closed grip) plus the shared base.

`nx` / `ny` are fractions of the **painted JPEG**, origin top-left of the photo.
Do **not** measure from a window screenshot. Gutters are not part of nx/ny.
Do not invent ids. Do not use the yellow F-14 sheet when it conflicts with this file.

## Pose

| Pose | What you see |
|---|---|
| Left | Same EVO R grip twisted open so the head hats are visible |
| Right | Same EVO R grip, white cap and trigger facing the camera |
| Base | Shared base under the shaft |

## Buttons

| HW | Physical | Pose | nx | ny | Group |
|---:|---|---|---:|---:|---|
| 1 | Red trigger, half pull | Right | 0.678 | 0.272 | pair 1/2 |
| 2 | Red trigger, full pull | Right | 0.678 | 0.272 | pair 1/2 |
| 3 | Red head button | Left | 0.395 | 0.250 | single |
| 4 | White cap | Right | 0.640 | 0.212 | single |
| 5 | Lower grip white button (not the base) | Right | 0.640 | 0.429 | single |
| 6 | 5-way right of red, up | Left | 0.428 | 0.245 | plus 6-10 |
| 7 | that 5-way, right | Left | 0.428 | 0.245 | plus 6-10 |
| 8 | that 5-way, down | Left | 0.428 | 0.245 | plus 6-10 |
| 9 | that 5-way, left | Left | 0.428 | 0.245 | plus 6-10 |
| 10 | that 5-way, center | Left | 0.428 | 0.245 | plus 6-10 |
| 11 | Top-right head 5-way, up | Left | 0.445 | 0.185 | plus 11-15 |
| 12 | that 5-way, right | Left | 0.445 | 0.185 | plus 11-15 |
| 13 | that 5-way, down | Left | 0.445 | 0.185 | plus 11-15 |
| 14 | that 5-way, left | Left | 0.445 | 0.185 | plus 11-15 |
| 15 | that 5-way, center | Left | 0.445 | 0.185 | plus 11-15 |
| 16 | Silver side wheel 5-way, up | Left | 0.400 | 0.370 | plus 16-20 |
| 17 | that wheel, right | Left | 0.400 | 0.370 | plus 16-20 |
| 18 | that wheel, down | Left | 0.400 | 0.370 | plus 16-20 |
| 19 | that wheel, left | Left | 0.400 | 0.370 | plus 16-20 |
| 20 | that wheel, center | Left | 0.400 | 0.370 | plus 16-20 |
| 21 | Ribbed paddle, push (not the red trigger) | Right | 0.695 | 0.277 | pair 21/22 |
| 22 | Ribbed paddle, pull | Right | 0.695 | 0.277 | pair 21/22 |
| 23 | En2 right knob, up | Base | 0.684 | 0.739 | pair 23/24 |
| 24 | En2 right knob, down | Base | 0.684 | 0.739 | pair 23/24 |
| 25 | En1 left knob, up | Base | 0.595 | 0.739 | pair 25/26 |
| 26 | En1 left knob, down | Base | 0.595 | 0.739 | pair 25/26 |
| 27 | Middle base pad | Base | 0.590 | 0.617 | pads |
| 28 | Left base pad | Base | 0.545 | 0.625 | pads |
| 29 | Right base pad | Base | 0.634 | 0.609 | pads |

## Hats

| HW | Physical | Pose | nx | ny |
|---:|---|---|---:|---:|
| 1 | Analog ministick, 8-way | Left | 0.378 | 0.190 |

6-10, 11-15, 16-20 are **buttons**, not DILL hats.

## Axes

| HW | Physical | Where | nx | ny |
|---:|---|---|---:|---:|
| 1 | Stick X roll | Gimbal / shaft | 0.430 | 0.575 |
| 2 | Stick Y pitch | Gimbal / shaft | 0.430 | 0.575 |
| 3 | Stick Z twist | Gimbal / shaft | 0.430 | 0.575 |
| 4 | Z slider between En1 and En2 | Base | 0.640 | 0.739 |

## Plus layout

```
        UP
LEFT  CENTER  RIGHT
       DOWN
```

- 6-10: 6 up, 8 down, 9 left, 7 right, 10 center
- 11-15: 11 up, 13 down, 14 left, 12 right, 15 center
- 16-20: 16 up, 18 down, 19 left, 17 right, 20 center

## Window chrome

Left column: H1, plus 11-15, plus 6-10, 3, plus 16-20, A1-A3
Right column: 4, 21/22, 1/2, 5
Bottom row: 25/26, 28, 27, 29, A4, 23/24

## Do not

- Do not treat the left and right grips as two devices.
- Do not put 1/2 on the left-pose trigger.
- Do not put 21/22 on the red trigger.
- Do not put 5 on the base.
- Do not swap En1/En2 (25/26 left knob, 23/24 right knob).
- Do not put A3 on the slider. A3 is twist at the gimbal. A4 is the slider.
- Do not copy nx/ny from a GUI screenshot that includes the black gutters.
