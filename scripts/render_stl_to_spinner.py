#!/usr/bin/env python3
"""
Headless Blender script to render an STL or STEP/STP file into a 360-degree
PNG image sequence for the PRISM Museum app's prototype spinner.

Prerequisites:
  brew install --cask blender

Usage:
  blender -b -P render_model_to_spinner.py -- <model_file> [options]
"""

import bpy
import sys
import os
import math
import argparse


def clean_scene():
    """Remove all default objects."""
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete()
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)


def setup_lighting():
    """Three-point product-shot lighting rig."""
    bpy.ops.object.light_add(type='AREA', radius=5, location=(5, -5, 5))
    key = bpy.context.active_object
    key.data.energy = 1500
    key.data.color = (1.0, 0.95, 0.9)

    bpy.ops.object.light_add(type='AREA', radius=4, location=(-5, -2, 3))
    fill = bpy.context.active_object
    fill.data.energy = 500
    fill.data.color = (0.9, 0.95, 1.0)

    bpy.ops.object.light_add(type='AREA', radius=5, location=(0, 5, 4))
    rim = bpy.context.active_object
    rim.data.energy = 1000


def import_model(filepath, color_hex=None):
    """Import STL or STP/STEP and return the joined mesh object."""
    ext = os.path.splitext(filepath)[1].lower()

    if ext == '.stl':
        print(f"Importing STL: {filepath}")
        bpy.ops.wm.stl_import(filepath=filepath)

    elif ext in ('.stp', '.step'):
        print(f"Importing STEP: {filepath}")
        imported_step = False

        # Try every known Blender STEP operator name across versions.
        # NOTE: hasattr() is unreliable on bpy.ops (lazy descriptors),
        # so we must try/except each call.
        step_ops = [
            'bpy.ops.wm.step_import',
            'bpy.ops.wm.stp_import',
            'bpy.ops.import_scene.occ_import_step',
        ]
        for op_path in step_ops:
            try:
                parts = op_path.split('.')
                func = bpy.ops
                for p in parts[1:]:
                    func = getattr(func, p)
                func(filepath=filepath)
                imported_step = True
                print(f"  Imported via {op_path}")
                break
            except (AttributeError, RuntimeError):
                continue

        if not imported_step:
            # Fallback: convert STP → STL via FreeCAD subprocess
            print("  No native STEP importer found. Attempting FreeCAD conversion…")
            import subprocess
            import tempfile

            tmp_stl = os.path.join(tempfile.gettempdir(), "converted_model.stl")
            freecad_script = (
                f"import FreeCAD, Part, Mesh\n"
                f"shape = Part.Shape()\n"
                f"shape.read(r'{filepath}')\n"
                f"Mesh.export([Mesh.Mesh(shape.tessellate(0.1))], r'{tmp_stl}')\n"
            )
            try:
                # Try common FreeCAD CLI names
                for cmd in ["freecadcmd", "FreeCADCmd", "freecad"]:
                    try:
                        subprocess.run(
                            [cmd, "-c", freecad_script],
                            check=True, capture_output=True, timeout=120,
                        )
                        imported_step = True
                        break
                    except FileNotFoundError:
                        continue

                if imported_step and os.path.isfile(tmp_stl):
                    print(f"  Converted to STL, importing…")
                    bpy.ops.wm.stl_import(filepath=tmp_stl)
                else:
                    raise RuntimeError("FreeCAD not found")

            except Exception:
                print("\n" + "=" * 60)
                print("ERROR: Cannot import STP/STEP files.")
                print()
                print("Blender 5.1 does not include a native STEP importer,")
                print("and FreeCAD is not installed for automatic conversion.")
                print()
                print("Options:")
                print("  1. Convert to STL first (recommended):")
                print("       brew install --cask freecad")
                print()
                sys.exit(1)

    elif ext in ('.obj', '.OBJ'):
        print(f"Importing OBJ: {filepath}")
        bpy.ops.wm.obj_import(filepath=filepath)

    else:
        print(f"ERROR: Unsupported format '{ext}'.")
        sys.exit(1)

    # Collect all mesh objects
    imported = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    if not imported:
        print("ERROR: No mesh objects found after import.")
        sys.exit(1)

    # Join into one object
    bpy.ops.object.select_all(action='DESELECT')
    for obj in imported:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = imported[0]
    if len(imported) > 1:
        bpy.ops.object.join()

    obj = bpy.context.active_object

    # Center and normalize scale
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    obj.location = (0, 0, 0)

    max_dim = max(obj.dimensions)
    if max_dim > 0:
        s = 4.0 / max_dim
        obj.scale = (s, s, s)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Flip model so the screen face points up (many CAD exports have it inverted)
    obj.rotation_euler = (math.radians(180), 0, 0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Apply material if requested, or if no materials exist (e.g. STL)
    if color_hex or not obj.data.materials:
        # If we have a custom color, or no materials at all, create a new one.
        # Otherwise (like in STEP) we keep the imported colors.
        mat_name = "KioskMaterial"
        mat = bpy.data.materials.get(mat_name) or bpy.data.materials.new(name=mat_name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")

        if bsdf:
            # Default PRISM blue if color_hex is missing
            c = (0.22, 0.74, 0.97, 1.0) # #38BDF8
            if color_hex:
                hex_val = color_hex.lstrip('#')
                rgb = tuple(int(hex_val[i:i+2], 16) / 255.0 for i in (0, 2, 4))
                c = (rgb[0], rgb[1], rgb[2], 1.0)

            bsdf.inputs["Base Color"].default_value = c
            bsdf.inputs["Metallic"].default_value = 0.5
            bsdf.inputs["Roughness"].default_value = 0.4

        if not obj.data.materials:
            obj.data.materials.append(mat)
        else:
            obj.data.materials[0] = mat

    return obj


def render_spinner(output_dir, num_frames=36, elevation_deg=47):
    """Orbit a camera 360° around the model and render each frame."""
    os.makedirs(output_dir, exist_ok=True)

    cam_distance = 8.0
    elev_rad = math.radians(elevation_deg)
    cam_y = -cam_distance * math.cos(elev_rad)
    cam_z = cam_distance * math.sin(elev_rad)
    cam_rot_x = math.radians(90 - elevation_deg)

    bpy.ops.object.camera_add(location=(0, cam_y, cam_z),
                               rotation=(cam_rot_x, 0, 0))
    camera = bpy.context.active_object
    bpy.context.scene.camera = camera

    bpy.ops.object.empty_add(location=(0, 0, 0))
    pivot = bpy.context.active_object
    pivot.name = "OrbitPivot"

    camera.parent = pivot
    tc = camera.constraints.new(type='TRACK_TO')
    tc.target = pivot
    tc.track_axis = 'TRACK_NEGATIVE_Z'
    tc.up_axis = 'UP_Y'

    _setup_render_settings()

    print(f"Rendering {num_frames} frames (elevation {elevation_deg}°) to {output_dir} …")

    for i in range(num_frames):
        angle = math.radians(360.0 * i / num_frames)
        pivot.rotation_euler = (0, 0, angle)
        bpy.context.view_layer.update()
        bpy.context.scene.render.filepath = os.path.join(output_dir, f"frame_{i:02d}.png")
        bpy.ops.render.render(write_still=True)
        print(f"  [{i+1}/{num_frames}] done")

    print(f"✅  All {num_frames} frames saved to {output_dir}")


def render_sphere(output_dir, cols=24, rows=7):
    """Render a full spherical grid: rows (elevation) × cols (azimuth).

    Output:  frame_r{row}_c{col}.png
    Flutter template maps  horizontal drag → col,  vertical drag → row.

    Default 7 rows span from -80° (near bottom) to +80° (near top-down).
    """
    # Default elevations for full spherical coverage
    if rows == 7:
        elevations = [-80, -50, -20, 10, 40, 65, 80]
    else:
        # Distribute evenly from -80 to +80
        elevations = [
            -80 + (160 * r / (rows - 1)) for r in range(rows)
        ]

    os.makedirs(output_dir, exist_ok=True)
    cam_distance = 8.0

    bpy.ops.object.camera_add(location=(0, -cam_distance, 0),
                               rotation=(math.radians(90), 0, 0))
    camera = bpy.context.active_object
    bpy.context.scene.camera = camera

    bpy.ops.object.empty_add(location=(0, 0, 0))
    pivot = bpy.context.active_object
    pivot.name = "OrbitPivot"

    camera.parent = pivot
    tc = camera.constraints.new(type='TRACK_TO')
    tc.target = pivot
    tc.track_axis = 'TRACK_NEGATIVE_Z'
    tc.up_axis = 'UP_Y'

    _setup_render_settings()

    total = rows * cols
    count = 0
    print(f"Rendering sphere: {rows} elevations × {cols} azimuths = {total} frames to {output_dir} …")

    for r, elev_deg in enumerate(elevations):
        elev_rad = math.radians(elev_deg)
        cam_y = -cam_distance * math.cos(elev_rad)
        cam_z = cam_distance * math.sin(elev_rad)
        cam_rot_x = math.radians(90 - elev_deg)
        camera.location = (0, cam_y, cam_z)
        camera.rotation_euler = (cam_rot_x, 0, 0)

        for c in range(cols):
            azimuth = math.radians(360.0 * c / cols)
            pivot.rotation_euler = (0, 0, azimuth)
            bpy.context.view_layer.update()

            bpy.context.scene.render.filepath = os.path.join(
                output_dir, f"frame_r{r:02d}_c{c:02d}.png")
            bpy.ops.render.render(write_still=True)
            count += 1
            print(f"  [{count}/{total}] elev={int(elev_deg):+d}° azimuth={int(360*c/cols)}°")

    # Write a manifest so Flutter knows the grid dimensions
    manifest = os.path.join(output_dir, "manifest.json")
    import json
    with open(manifest, 'w') as f:
        json.dump({"rows": rows, "cols": cols, "elevations": elevations}, f, indent=2)

    print(f"✅  All {total} frames + manifest saved to {output_dir}")


def _setup_render_settings():
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_EEVEE'
    scene.render.film_transparent = True
    scene.render.resolution_x = 1080
    scene.render.resolution_y = 1080
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'


# ── Main ──────────────────────────────────────────────────────────────────────
if __name__ == "__main__":
    if "--" not in sys.argv:
        print("Usage: blender -b -P render_model_to_spinner.py -- <model_file> [options]")
        sys.exit(1)

    try:
        dash_index = sys.argv.index("--")
        script_args = sys.argv[dash_index + 1:]
    except ValueError:
        script_args = []

    parser = argparse.ArgumentParser(
        description="Render a 3D model to a 360° image sequence.")
    parser.add_argument("model", help="Path to .stl, .stp, .step, or .obj file")
    parser.add_argument("-o", "--output", default="./spinner_output",
                        help="Output directory (default: ./spinner_output)")
    parser.add_argument("-n", "--frames", type=int, default=36,
                        help="Number of azimuth frames (default: 36)")
    parser.add_argument("-c", "--color", help="Hex color for the model (e.g. #38BDF8)")
    parser.add_argument("-e", "--elevation", type=int, default=47,
                        help="Camera elevation angle in degrees (default: 47)")
    parser.add_argument("--sphere", action="store_true",
                        help="Enable spherical rendering (azimuth × elevation grid)")
    parser.add_argument("--rows", type=int, default=7,
                        help="Number of elevation rows for --sphere mode (default: 7)")
    opts = parser.parse_args(script_args)

    model_path = os.path.abspath(opts.model)
    out_dir = os.path.abspath(opts.output)

    if not os.path.isfile(model_path):
        print(f"File not found: {model_path}")
        sys.exit(1)

    clean_scene()
    setup_lighting()
    import_model(model_path, opts.color)

    if opts.sphere:
        render_sphere(out_dir, cols=opts.frames, rows=opts.rows)
    else:
        render_spinner(out_dir, opts.frames, opts.elevation)
