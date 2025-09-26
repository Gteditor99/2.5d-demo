# Recoil Debug Menu

The recoil debug menu lets you inspect and tweak weapon recoil at runtime.

## Opening the menu

- Ensure the player scene is running.
- Press the `debug` input action (binds to `F3` by default unless remapped) to toggle the menu.
- The panel can be dragged around by grabbing anywhere on its frame.

## Editing recoil values live

- Use the spin boxes under each group to adjust the active weapon's `RecoilData` resource.
- Changes are applied immediately to the live `RecoilData` instance, so new shots reflect the updated values without reloading the weapon.
- Click **Reset** to restore the values that were present when the weapon was equipped.
- Click **Copy JSON** to place the current recoil settings onto the clipboard for sharing or committing back into your resource.

## Graph view

- The six graphs on the right visualize positional and rotational recoil curves.
- A yellow vertical line shows the current recoil playback progress.
- When no weapon is connected, the graphs display a looping fallback animation so you can reposition the panel.

## Notes

- The menu automatically rebinds to the active `ViewModelComponent`, so switching weapons updates the displayed data.
- Curve editing is not yet supported from the menu; adjust curve resources in the Godot editor if needed.
