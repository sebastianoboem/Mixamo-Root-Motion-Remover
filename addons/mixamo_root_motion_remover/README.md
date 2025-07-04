# Mixamo Root Motion Remover

An addon for Godot 4.4+ that automatically removes root motion from Mixamo locomotion animations.

## Features

- **Context menu**: Adds "Remove Mixamo Root Motion" to the right-click menu on AnimationLibrary files in the FileSystem
- **Automatic detection**: Automatically identifies locomotion animations by searching for keywords "forward", "left", "right", "backward" in animation names
- **Selective removal**: Only modifies locomotion animations, leaving other animations intact
- **Y-axis preservation**: Maintains vertical movements (jumps, landings) by zeroing only X and Z positions
- **Multiple selection support**: Can process multiple AnimationLibrary files simultaneously

## Installation

1. Copy the `addons/mixamo_root_motion_remover` folder to your Godot project
2. Go to **Project > Project Settings > Plugins**
3. Search for "Mixamo Root Motion Remover" and enable it

## How to Use

1. Import your Mixamo animations into the project
2. In the Godot **FileSystem**, **right-click** on an AnimationLibrary file (`.res`)
3. Select **"Remove Mixamo Root Motion"** from the context menu
4. The addon will automatically process all locomotion animations in the selected file

## Supported Animations

The addon automatically identifies locomotion animations by searching for these terms in the names:
- `forward`
- `left` 
- `right`
- `backward`

## What It Does

For each locomotion animation found:
1. Finds the "Hips" track in the animation
2. For each keyframe in the Hips track:
   - Sets X position to 0.0
   - Sets Z position to 0.0  
   - Keeps Y position unchanged

## Console Output

The addon provides detailed feedback in the Godot console:
- List of processed animations
- Number of modified keyframes per animation
- Final process summary

## Compatibility

- **Godot**: 4.4+
- **Animations**: Mixamo and other animations with Hips track
- **Format**: AnimationLibrary

## Technical Notes

- The addon connects to the FileSystem dock context menu using the same technique as mixamo_animation_retargeter
- The "Remove Mixamo Root Motion" option appears only when a `.res` file containing an AnimationLibrary is selected
- The addon specifically searches for `TYPE_POSITION_3D` tracks that contain "Hips" in the name
- Changes are permanent and automatically saved, it's recommended to backup original animations
- The addon does not modify non-locomotion animations
- Supports multiple AnimationLibrary file selection
- Provides detailed feedback in console and confirmation dialogs 