"""Render the included GLBs as consistent transparent sprites with Blender.

blender -b -t 2 --python scripts/render_models.py -- cat_orange [cat_blue ...]
Original generated images remain in assets/sprites; renders go in assets/renders.
"""
import json
from pathlib import Path
import sys

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]


def render(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    bpy.ops.import_scene.gltf(filepath=str(ROOT / "assets/models" / f"{name}.glb"))
    meshes = [obj for obj in scene.objects if obj.type == "MESH"]
    points = [obj.matrix_world @ Vector(corner) for obj in meshes for corner in obj.bound_box]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    center = (low + high) / 2
    extent = max(high - low)
    # Put imported roots under a normalization transform without changing materials.
    parent = bpy.data.objects.new("AssetRoot", None)
    scene.collection.objects.link(parent)
    for obj in list(scene.objects):
        if obj != parent and obj.parent is None:
            obj.parent = parent
    scale = 2.0 / extent
    parent.scale = (scale,) * 3
    parent.location = -center * scale + Vector((0, 0, 1))
    bpy.ops.object.camera_add(location=(0, -7, 2.1))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((0, 0, 1)) - camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 2.45
    scene.camera = camera
    for location, energy, size in [((-3, -4, 6), 450, 5), ((3, -2, 3), 250, 4), ((0, 3, 5), 350, 3)]:
        bpy.ops.object.light_add(type='AREA', location=location)
        lamp = bpy.context.object
        lamp.data.energy = energy
        lamp.data.shape = 'DISK'
        lamp.data.size = size
        lamp.rotation_euler = (Vector((0, 0, 1)) - lamp.location).to_track_quat('-Z', 'Y').to_euler()
    scene.world = bpy.data.worlds.new("Studio")
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (0.55, 0.6, 0.65, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = 0.35
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.view_settings.view_transform = 'Standard'
    scene.render.filepath = str(ROOT / "assets/renders" / f"{name}.png")
    triangles = sum(len(poly.vertices) - 2 for obj in meshes for poly in obj.data.polygons)
    print(json.dumps({"asset": name, "triangles": triangles, "render": scene.render.filepath}))
    bpy.ops.render.render(write_still=True)


for asset_name in sys.argv[sys.argv.index('--') + 1:]:
    if not asset_name.replace('_', '').isalnum():
        raise ValueError('Invalid asset name')
    render(asset_name)
