# Vehicle Soccer Prototype (Godot 4)

A separate starter project for an arcade physics-based vehicle-soccer game. It lives in this folder so it does not overwrite the existing **Nerf Blaster Arena 3D** project.

## Requirements

- Godot 4.x
- No third-party assets are required for the first prototype.

## Open and run

1. Download or clone this repository.
2. In Godot, choose **Import** and select `vehicle-soccer-prototype/project.godot`.
3. Open the project and press **F6** or **F5** to run the main scene.
4. Use the controls below to test the prototype.

## Controls

- **W / Up:** accelerate
- **S / Down:** reverse
- **A / D** or **Left / Right:** steer
- **Space:** jump, then double-jump
- **Shift:** boost
- **Ctrl:** brake
- **Q:** toggle Car Cam / Ball Cam

W/S and A/D also drive the basic aerial pitch/roll controls while airborne.

## Included framework

- Arcade car controller with acceleration, steering, braking, jump, double-jump, air rotation, and boost meter.
- Rigid-body ball with bounce, damping, and car-hit impulses.
- Car-follow and ball-tracking camera modes.
- Procedurally created prototype arena, cars, ball, goal lines, and HUD.
- Match manager with score, timer, kickoff reset, and match states.
- Goal-plane crossing check that tests whether the ball fits inside the goal opening.

## Important prototype limitations

This is a **starting prototype**, not a finished competitive game. It has not been run through the Godot editor or tested across machines in this commit. Please treat it as code to import and validate, and report any editor errors so they can be corrected.

- The arena currently uses flat walls. Smooth curved floor-to-wall and ceiling transitions need custom collision geometry and a surface-normal driving controller.
- The away car is a non-player placeholder; local two-player controls are not yet mapped.
- The networking architecture is not implemented yet. Online play requires an authoritative server, synchronized car inputs/states, shared ball state, and server-verified scoring. Do not treat client-side physics as secure multiplayer.
- Goal geometry and high-speed crossing should be tested and tuned in-game.
- This project is separate from the existing Nerf Blaster Arena 3D files.

## Suggested implementation order

1. Import the project and fix any Godot parser/editor errors.
2. Tune car handling and ball collision.
3. Build curved arena meshes and surface-normal driving.
4. Finish goal geometry, kickoff states, and end-of-match UI.
5. Add authoritative multiplayer and test with two separate clients.
