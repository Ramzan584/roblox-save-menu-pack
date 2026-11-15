"""Run with Blender --background --factory-startup --python this.py -- --output DIR.
Original CC0 conversion tool for assets/save-lobby/generated/SaveLobbyKit.rbxmx.
"""
import argparse
import json
import math
from pathlib import Path
import sys
import xml.etree.ElementTree as ET


def read_models(path, meters):
    if not math.isfinite(meters) or not .01 <= meters <= 10:
        raise ValueError('meters-per-stud must be between .01 and 10')
    raw = path.read_bytes()
    if len(raw) > 2_000_000 or b'<!DOCTYPE' in raw.upper() or b'<!ENTITY' in raw.upper():
        raise ValueError('Unsupported XML size or declarations')
    root = ET.fromstring(raw)
    if root.tag != 'roblox' or root.get('version') != '4':
        raise ValueError('Expected Roblox XML v4')
    wrapper = root.findall('Item')
    if len(wrapper) != 1 or wrapper[0].get('class') != 'Model':
        raise ValueError('Expected one model wrapper')
    result = []
    names = set()
    for model in wrapper[0].findall('Item'):
        if model.get('class') != 'Model':
            raise ValueError('Only nested models supported')
        name = model.findtext('./Properties/string[@name="Name"]')
        if not name or not name.isascii() or not name.isalnum() or name in names:
            raise ValueError('Model names must be unique ASCII letters/digits')
        names.add(name)
        parts = []
        part_names = set()
        for item in model.findall('Item'):
            if item.get('class') != 'Part' or item.findall('Item'):
                raise ValueError('Only plain block Parts supported')
            props = item.find('Properties')
            part_name = props.findtext('string[@name="Name"]')
            if not part_name or part_name in part_names:
                raise ValueError('Missing or duplicate part name')
            part_names.add(part_name)
            if props.findtext('token[@name="shape"]') != '1':
                raise ValueError('Only block shape supported')
            def values(tag, axes):
                vals = [float(props.findtext(f'{tag}/{a}')) for a in axes]
                if not all(math.isfinite(v) for v in vals):
                    raise ValueError('Nonfinite geometry')
                return vals
            size = values('Vector3[@name="size"]', 'XYZ')
            pos = values('CoordinateFrame[@name="CFrame"]', 'XYZ')
            rotation = values('CoordinateFrame[@name="CFrame"]', [f'R{r}{c}' for r in range(3) for c in range(3)])
            if rotation != [1,0,0,0,1,0,0,0,1] or min(size) <= 0:
                raise ValueError('Only positive axis-aligned boxes supported')
            color = values('Color3[@name="Color"]', 'RGB')
            if not all(0 <= c <= 1 for c in color):
                raise ValueError('Color outside 0..1')
            parts.append(dict(name=part_name, size=[size[0]*meters,size[2]*meters,size[1]*meters],
                position=[pos[0]*meters,-pos[2]*meters,pos[1]*meters], color=color))
        if not parts:
            raise ValueError('Empty model')
        # Each export origin is centered in X/Y, with its bottom on Z=0.
        low = [min(p['position'][i]-p['size'][i]/2 for p in parts) for i in range(3)]
        high = [max(p['position'][i]+p['size'][i]/2 for p in parts) for i in range(3)]
        origin = [(low[0]+high[0])/2,(low[1]+high[1])/2,low[2]]
        for p in parts:
            p['position'] = [v-o for v,o in zip(p['position'], origin)]
        result.append(dict(name=name, parts=parts, bounds_m=[h-l for h,l in zip(high,low)]))
    if not result:
        raise ValueError('No models')
    return result


def run(source, output, meters):
    import bpy
    from mathutils import Vector
    models = read_models(source, meters)
    if output.exists():
        raise ValueError('Output directory must be new')
    output.mkdir(parents=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1
    report = dict(blender=bpy.app.version_string, meters_per_stud=meters, models=[],
        export=dict(axis_forward='-Z', axis_up='Y', global_scale=1, apply_unit_scale=True))
    for index, model in enumerate(models):
        objects = []
        for part in model['parts']:
            bpy.ops.mesh.primitive_cube_add(size=1, location=part['position'])
            obj = bpy.context.object
            obj.name = model['name']+'_'+part['name']
            obj.dimensions = part['size']
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
            mat = bpy.data.materials.new(obj.name+'_Color')
            mat.diffuse_color = (*part['color'],1)
            mat.use_nodes = True
            mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (*part['color'],1)
            obj.data.materials.append(mat)
            objects.append(obj)
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
            assert all(abs(v-1)<1e-6 for v in obj.scale)
        filename = model['name']+'.fbx'
        bpy.ops.export_scene.fbx(filepath=str(output/filename), use_selection=True,
            object_types={'MESH'}, axis_forward='-Z', axis_up='Y', global_scale=1,
            apply_unit_scale=True, bake_anim=False, add_leaf_bones=False)
        assert (output/filename).stat().st_size > 0
        # Reimport each FBX and check world bounds before deleting the verification copy.
        bpy.ops.object.select_all(action='DESELECT')
        bpy.ops.import_scene.fbx(filepath=str(output/filename))
        imported = list(bpy.context.selected_objects)
        assert len(imported) == len(objects), 'FBX object count mismatch'
        verts = [obj.matrix_world @ Vector(c) for obj in imported for c in obj.bound_box]
        bounds = [max(v[i] for v in verts)-min(v[i] for v in verts) for i in range(3)]
        assert all(abs(a-b)<.001 for a,b in zip(bounds,model['bounds_m'])), 'FBX scale mismatch'
        bpy.ops.object.delete(use_global=False)
        report['models'].append(dict(name=model['name'], parts=len(objects), bounds_m=bounds,
            file=filename, reimport_verified=True))
        for obj in objects:
            obj.location.x += (index%3)*4
            obj.location.y += (index//3)*4
    bpy.ops.object.camera_add(location=(12,-14,14))
    camera = bpy.context.object
    camera.rotation_euler = (Vector((4,2,1))-camera.location).to_track_quat('-Z','Y').to_euler()
    camera.data.type='ORTHO'
    camera.data.ortho_scale=13
    scene.camera=camera
    bpy.ops.object.light_add(type='AREA', location=(4,-4,12))
    bpy.context.object.data.energy=1800
    bpy.context.object.data.shape='DISK'
    bpy.context.object.data.size=10
    scene.world.color=(.22,.22,.22)
    scene.render.engine='CYCLES'
    scene.cycles.samples=16
    scene.render.resolution_x=960
    scene.render.resolution_y=720
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.render.filepath=str(output/'preview.png')
    bpy.ops.wm.save_as_mainfile(filepath=str(output/'SaveLobby.blend'))
    bpy.ops.render.render(write_still=True)
    (output/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path(__file__).resolve().parents[1]/'assets/save-lobby/generated/SaveLobbyKit.rbxmx')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--meters-per-stud', type=float, default=.28)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    run(args.source.resolve(),args.output.resolve(),args.meters_per_stud)
