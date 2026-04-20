#!/usr/bin/env python3
"""
Headless Blender script to render a .step file into a 360-degree PNG image sequence.

Prerequisites:
1. Install Blender (https://www.blender.org/)
2. Make sure the 'blender' executable is in your PATH.

Usage:
blender --background --python render_step.py -- /path/to/model.step /path/to/output_folder/

This script will:
1. Clear the default scene.
2. Import the provided .step file.
3. Center and scale the model.
4. Setup a 3-point lighting rig and a camera.
5. Orbit the camera 360 degrees around the Z-axis.
6. Render 36 frames (10 degrees each) with a transparent background to the output folder.
"""

import bpy
import sys
import os
import math

def clean_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()

def setup_lighting():
    # Key light
    bpy.ops.object.light_add(type='AREA', radius=5, location=(5, -5, 5))
    key_light = bpy.context.active_object
    key_light.data.energy = 1500
    
    # Fill light
    bpy.ops.object.light_add(type='AREA', radius=5, location=(-5, -2, 3))
    fill_light = bpy.context.active_object
    fill_light.data.energy = 500
    
    # Back light
    bpy.ops.object.light_add(type='AREA', radius=5, location=(0, 5, 4))
    back_light = bpy.context.active_object
    back_light.data.energy = 1000

def import_and_center_step(filepath):
    # In modern Blender (4.0+), STEP import is built-in via 'occ_import_step'
    # or the older Stepper addon.
    if hasattr(bpy.ops.import_scene, 'occ_import_step'):
        print("Using new OCC STEP importer")
        bpy.ops.import_scene.occ_import_step(filepath=filepath)
    elif hasattr(bpy.ops.import_shape, 'step'):
        bpy.ops.import_shape.step(filepath=filepath)
    else:
        print("Warning: Could not find strict STEP importer. Falling back to alternative formats if possible.")

    # Select all imported objects
    bpy.ops.object.select_all(action='SELECT')
    if not bpy.context.selected_objects:
        print("Nothing imported!")
        return None
        
    # Join objects into one
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object

    # Center origin to geometry
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    obj.location = (0, 0, 0)
    
    # Scale to fit within a 4x4x4 box roughly
    max_dim = max(obj.dimensions)
    if max_dim > 0:
        scale_factor = 4.0 / max_dim
        obj.scale = (scale_factor, scale_factor, scale_factor)
        
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj

def render_spinner(output_dir, frames=36):
    os.makedirs(output_dir, exist_ok=True)
    
    # Setup Camera
    bpy.ops.object.camera_add(location=(0, -8, 2), rotation=(math.radians(75), 0, 0))
    camera = bpy.context.active_object
    bpy.context.scene.camera = camera
    
    # Add an empty at origin to rotate the camera around
    bpy.ops.object.empty_add(location=(0,0,0))
    target = bpy.context.active_object
    
    # Parent camera to target
    camera.parent = target
    
    # Track constraint
    constraint = camera.constraints.new(type='TRACK_TO')
    constraint.target = target
    constraint.track_axis = 'TRACK_NEGATIVE_Z'
    constraint.up_axis = 'UP_Y'
    
    # Render settings
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.render.film_transparent = True
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1080
    scene.render.image_settings.color_mode = 'RGBA'
    scene.cycles.samples = 64 # low samples for quick rendering of the spinner
    
    print(f"Rendering {frames} frames to {output_dir}")
    
    for i in range(frames):
        # Rotate target by 360/frames degrees
        angle = math.radians(360.0 * i / frames)
        target.rotation_euler = (0, 0, angle)
        
        bpy.context.view_layer.update()
        
        scene.render.filepath = os.path.join(output_dir, f"frame_{i:02d}.png")
        bpy.ops.render.render(write_still=True)

if __name__ == "__main__":
    if "--" not in sys.argv:
        print("Usage: blender -b -P render_step.py -- <input.step> <output_dir>")
        sys.exit(1)
        
    args = sys.argv[sys.argv.index("--") + 1:]
    if len(args) < 2:
        print("Missing arguments.")
        sys.exit(1)
        
    input_file = args[0]
    output_dir = args[1]
    
    clean_scene()
    setup_lighting()
    import_and_center_step(input_file)
    render_spinner(output_dir)
    print("Done!")
