"""
Hourbloom - procedural low-poly asset builder for Blender 4.x / 5.x.

Builds every 3D model used by the prototype, saves an editable .blend for each
(art/blender/models/*.blend) and exports a .glb for Godot (assets/models/*.glb).

Run with Blender:   blender --background --python art/blender/build_assets.py
Or with the bpy pip module:   python3 art/blender/build_assets.py

Style: "painted golden hour" - chunky low-poly shapes, flat shading,
soft bevels, warm colours. Small files: every model is a few KB.
"""

import math
import os

import bpy
import bmesh

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GLB_DIR = os.path.join(ROOT, "assets", "models")
BLEND_DIR = os.path.join(ROOT, "art", "blender", "models")
os.makedirs(GLB_DIR, exist_ok=True)
os.makedirs(BLEND_DIR, exist_ok=True)

# ---------------------------------------------------------------- palette
C = {
    "terracotta": (0.79, 0.44, 0.35),
    "terracotta_light": (0.85, 0.54, 0.45),
    "soil": (0.23, 0.16, 0.13),
    "leaf": (0.37, 0.75, 0.56),
    "stem": (0.30, 0.62, 0.45),
    "petal": (1.0, 1.0, 1.0),          # tinted per genre in Godot
    "center": (1.0, 0.96, 0.81),
    "ink": (0.17, 0.15, 0.25),
    "cream": (1.0, 0.97, 0.91),
    "scarf": (1.0, 0.54, 0.36),
    "skin": (0.78, 0.56, 0.42),
    "coral": (1.0, 0.48, 0.42),
    "coral_dark": (0.70, 0.30, 0.28),
    "eye": (1.0, 0.93, 0.93),
    "gold": (1.0, 0.83, 0.42),
    "gold_glow": (1.0, 0.74, 0.30),
    "tower": (0.36, 0.33, 0.46),
    "tower_b": (0.43, 0.38, 0.52),
    "tower_c": (0.30, 0.29, 0.40),
    "window": (1.0, 0.83, 0.42),
    "deck": (0.55, 0.42, 0.36),
    "frame": (0.96, 0.93, 0.86),
    "glass": (0.75, 0.88, 1.0),
    "slab": (0.24, 0.20, 0.36),
    "pipe": (0.85, 0.81, 0.91),
    "pad": (1.0, 1.0, 1.0),
}

_materials = {}


def mat(name, color, emission=0.0, alpha=1.0, rough=0.7, metal=0.0):
    key = (name, color, emission, alpha)
    if key in _materials:
        return _materials[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        try:
            m.surface_render_method = "BLENDED"
        except AttributeError:
            m.blend_method = "BLEND"
    _materials[key] = m
    return m


# ---------------------------------------------------------------- helpers
def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _materials.clear()


def finish(obj, material, name=None, bevel=0.0, smooth=False):
    if name:
        obj.name = name
        obj.data.name = name
    obj.data.materials.clear()
    obj.data.materials.append(material)
    if bevel > 0.0:
        mod = obj.modifiers.new("Bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        mod.limit_method = "ANGLE"
    for p in obj.data.polygons:
        p.use_smooth = smooth
    return obj


def cylinder(name, r1, r2, depth, verts=8, loc=(0, 0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    return o


def box(name, size, loc=(0, 0, 0), rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.name = name
    return o


def sphere(name, r, loc=(0, 0, 0), scale=(1, 1, 1), subdiv=2, uv=False, seg=12, rings=8):
    if uv:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=loc)
    else:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.name = name
    return o


def join(objs, name):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    o.data.name = name
    return o


def export(name):
    # Bake transforms so every part shares the model's origin (0, 0, 0).
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.select_all(action="DESELECT")
    # Godot is Y-up; glTF exporter converts Blender Z-up automatically.
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(BLEND_DIR, name + ".blend"))
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(GLB_DIR, name + ".glb"),
        export_format="GLB",
        export_apply=True,
        export_yup=True,
        use_selection=False,
    )
    print("  built", name)


# ---------------------------------------------------------------- models
def build_pot():
    reset()
    body = cylinder("Pot", 0.42, 0.55, 0.7, verts=10, loc=(0, 0, 0.35))
    # flip so it narrows at the bottom
    body.rotation_euler = (math.pi, 0, 0)
    bpy.ops.object.transform_apply(rotation=True)
    finish(body, mat("Terracotta", C["terracotta"]), "Pot", bevel=0.03)
    rim = cylinder("Rim", 0.62, 0.62, 0.14, verts=10, loc=(0, 0, 0.72))
    finish(rim, mat("TerracottaLight", C["terracotta_light"]), "Rim", bevel=0.03)
    soil = cylinder("Soil", 0.52, 0.52, 0.04, verts=10, loc=(0, 0, 0.78))
    finish(soil, mat("Soil", C["soil"]), "Soil")
    export("pot")


def build_flower():
    reset()
    stem = cylinder("Stem", 0.05, 0.035, 1.0, verts=6, loc=(0, 0, 0.5))
    finish(stem, mat("Stem", C["stem"]), "Stem", smooth=True)
    leaves = []
    for i, (z, ang) in enumerate([(0.35, 0.0), (0.6, math.pi)]):
        lf = sphere("Leaf%d" % i, 0.2, loc=(0.18 * math.cos(ang), 0.18 * math.sin(ang), z), scale=(1.0, 0.45, 0.18), subdiv=1)
        lf.rotation_euler = (0, -0.5 if ang == 0 else 0.5, ang)
        leaves.append(lf)
    lv = join(leaves, "Leaves")
    finish(lv, mat("Leaf", C["leaf"]), "Leaves")
    petals = []
    for i in range(5):
        a = i / 5 * math.tau
        p = sphere("Petal%d" % i, 0.2, loc=(0.2 * math.cos(a), 0.2 * math.sin(a), 1.05), scale=(1.0, 0.62, 0.22), subdiv=1)
        p.rotation_euler = (0, 0.35, a)
        petals.append(p)
    pt = join(petals, "Petals")
    finish(pt, mat("Petal", C["petal"], rough=0.5), "Petals")
    center = sphere("Center", 0.12, loc=(0, 0, 1.08), subdiv=2)
    finish(center, mat("FlowerCenter", C["center"], emission=0.6), "Center", smooth=True)
    export("flower")


def build_glider():
    reset()
    # Ira's sky glider: a cream delta wing, Ira seated on top, orange scarf.
    bm = bmesh.new()
    pts = [(0, 1.1, 0), (0.95, -0.55, 0), (0.0, -0.3, 0.05), (-0.95, -0.55, 0)]
    verts = [bm.verts.new(p) for p in pts]
    top = [bm.verts.new((x, y, z + 0.08)) for (x, y, z) in pts]
    bm.faces.new(verts[::-1])
    bm.faces.new(top)
    for i in range(4):
        j = (i + 1) % 4
        bm.faces.new((verts[i], verts[j], top[j], top[i]))
    me = bpy.data.meshes.new("Wing")
    bm.to_mesh(me)
    wing = bpy.data.objects.new("Wing", me)
    bpy.context.collection.objects.link(wing)
    finish(wing, mat("Cream", C["cream"]), "Wing", bevel=0.02)
    body = sphere("Body", 0.22, loc=(0, 0.0, 0.3), scale=(0.85, 0.8, 1.1), subdiv=2)
    finish(body, mat("Ink", C["ink"]), "Body", smooth=True)
    head = sphere("Head", 0.15, loc=(0, 0.05, 0.62), subdiv=2)
    finish(head, mat("Skin", C["skin"]), "Head", smooth=True)
    hair = sphere("Hair", 0.16, loc=(0, -0.02, 0.68), scale=(1, 1, 0.75), subdiv=2)
    finish(hair, mat("Hair", C["ink"]), "Hair", smooth=True)
    scarf = box("Scarf", (0.12, 0.6, 0.04), loc=(0.12, -0.38, 0.45), rot=(0.4, 0, 0.25))
    finish(scarf, mat("Scarf", C["scarf"]), "Scarf", bevel=0.01)
    export("glider")


def build_drone():
    reset()
    body = box("Body", (0.9, 0.7, 0.5), loc=(0, 0, 0))
    finish(body, mat("Coral", C["coral"]), "Body", bevel=0.12)
    band = box("Band", (0.94, 0.74, 0.1), loc=(0, 0, -0.05))
    finish(band, mat("CoralDark", C["coral_dark"]), "Band", bevel=0.03)
    eye = cylinder("Eye", 0.17, 0.17, 0.08, verts=12, loc=(0, -0.36, 0.05), rot=(math.pi / 2, 0, 0))
    finish(eye, mat("Ink", C["ink"]), "Eye")
    pupil = cylinder("Pupil", 0.07, 0.07, 0.1, verts=10, loc=(0, -0.38, 0.05), rot=(math.pi / 2, 0, 0))
    finish(pupil, mat("EyeGlow", C["eye"], emission=1.2), "Pupil")
    arms = []
    for sx in (-1, 1):
        arms.append(box("Arm", (0.5, 0.08, 0.06), loc=(sx * 0.6, 0, 0.28)))
    a = join(arms, "Arms")
    finish(a, mat("CoralDark", C["coral_dark"]), "Arms")
    rotors = []
    for sx in (-1, 1):
        rotors.append(cylinder("Rotor", 0.26, 0.26, 0.03, verts=12, loc=(sx * 0.82, 0, 0.33)))
    r = join(rotors, "Rotors")
    finish(r, mat("RotorGlass", C["eye"], alpha=0.55), "Rotors")
    export("drone")


def build_orb():
    reset()
    o = sphere("Orb", 0.3, subdiv=2)
    finish(o, mat("LightOrb", C["gold"], emission=2.5, rough=0.3), "Orb")
    halo = sphere("Halo", 0.42, subdiv=2)
    finish(halo, mat("Halo", C["gold_glow"], emission=1.0, alpha=0.25), "Halo", smooth=True)
    export("orb")


def build_sunday():
    reset()
    body = sphere("Body", 0.4, subdiv=3)
    finish(body, mat("SundayGold", C["gold"], emission=0.35, rough=0.4), "Body", smooth=True)
    belly = sphere("Belly", 0.22, loc=(-0.07, -0.25, 0.08), scale=(1, 0.5, 1), subdiv=2)
    finish(belly, mat("SundayLight", C["center"], emission=0.3), "Belly", smooth=True)
    eyes = []
    for sx in (-1, 1):
        eyes.append(box("Eye", (0.07, 0.04, 0.13), loc=(sx * 0.12, -0.38, 0.07)))
    e = join(eyes, "Eyes")
    finish(e, mat("Ink", C["ink"]), "Eyes", bevel=0.015)
    ant = cylinder("Antenna", 0.025, 0.02, 0.3, verts=6, loc=(0.05, 0, 0.5), rot=(0, 0.3, 0))
    finish(ant, mat("SundayGold", C["gold"]), "Antenna")
    tip = sphere("Tip", 0.06, loc=(0.1, 0, 0.65), subdiv=1)
    finish(tip, mat("SundayLight", C["center"], emission=1.5), "Tip", smooth=True)
    export("sunday")


def build_tower(name, w, d, h, color_key, seed):
    reset()
    import random
    rnd = random.Random(seed)
    t = box("Tower", (w, d, h), loc=(0, 0, h / 2))
    finish(t, mat("Tower", C[color_key]), "Tower", bevel=0.04)
    roof = box("Roof", (w * 0.6, d * 0.6, 0.4), loc=(0, 0, h + 0.2))
    finish(roof, mat("TowerRoof", tuple(c * 0.85 for c in C[color_key])), "Roof", bevel=0.03)
    wins = []
    rows = int(h / 0.9)
    for r in range(rows):
        z = 0.7 + r * 0.9
        for side in range(4):
            if rnd.random() < 0.55:
                continue
            ang = side * math.pi / 2
            dist = (d if side % 2 == 0 else w) / 2 + 0.01
            span = (w if side % 2 == 0 else d)
            for k in range(2):
                off = (k - 0.5) * span * 0.45
                x = math.sin(ang) * dist + math.cos(ang) * off
                y = -math.cos(ang) * dist + math.sin(ang) * off
                wins.append(box("Win", (0.22, 0.04, 0.32), loc=(x, y, z), rot=(0, 0, ang)))
    if wins:
        wn = join(wins, "Windows")
        finish(wn, mat("WindowGlow", C["window"], emission=2.0), "Windows")
    export(name)


def build_greenhouse():
    reset()
    deck = box("Deck", (9.0, 6.0, 0.3), loc=(0, 0, -0.15))
    finish(deck, mat("Deck", C["deck"]), "Deck", bevel=0.05)
    # planks
    planks = []
    for i in range(12):
        planks.append(box("Plank", (0.04, 5.9, 0.02), loc=(-4.2 + i * 0.75, 0, 0.01)))
    pl = join(planks, "Planks")
    finish(pl, mat("PlankLine", tuple(c * 0.75 for c in C["deck"])), "Planks")
    # arched glass frame behind the pots
    beams = []
    for i in range(7):
        x = -3.6 + i * 1.2
        beams.append(box("Post", (0.08, 0.08, 3.0), loc=(x, 2.6, 1.5)))
    # curved roof ribs: a quarter arch from the back wall up and over the deck
    for i in range(7):
        x = -3.6 + i * 1.2
        for k in range(8):
            a0 = k / 8 * (math.pi / 2)
            a1 = (k + 1) / 8 * (math.pi / 2)
            p0 = (2.6 - math.sin(a0) * 2.4, 3.0 + math.sin(a0) * 1.2)
            p1 = (2.6 - math.sin(a1) * 2.4, 3.0 + math.sin(a1) * 1.2)
            mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2)
            length = math.dist(p0, p1)
            ang = math.atan2(p1[1] - p0[1], p1[0] - p0[0])
            beams.append(box("Arch", (0.07, length + 0.02, 0.07), loc=(x, mid[0], mid[1]), rot=(ang, 0, 0)))
    beams.append(box("TopBeam", (7.3, 0.08, 0.08), loc=(0, 2.6, 3.0)))
    beams.append(box("RidgeBeam", (7.3, 0.08, 0.08), loc=(0, 0.2, 4.2)))
    fr = join(beams, "Frame")
    finish(fr, mat("Frame", C["frame"], rough=0.4), "Frame")
    glass = box("Glass", (7.2, 0.03, 2.9), loc=(0, 2.62, 1.5))
    finish(glass, mat("Glass", C["glass"], alpha=0.18, rough=0.1), "Glass")
    # low planter boxes at the sides
    for sx in (-1, 1):
        pb = box("Planter", (0.6, 4.6, 0.5), loc=(sx * 4.1, 0, 0.25))
        finish(pb, mat("Terracotta", C["terracotta"]), "Planter", bevel=0.04)
        hedge = sphere("Hedge", 0.4, loc=(sx * 4.1, 0, 0.6), scale=(0.8, 5.6, 0.8), subdiv=2)
        finish(hedge, mat("Leaf", C["leaf"]), "Hedge")
    # string lights
    bulbs = []
    for i in range(15):
        x = -3.5 + i * 0.5
        z = 2.85 - math.sin(i / 14 * math.pi) * 0.35
        bulbs.append(sphere("Bulb", 0.06, loc=(x, 2.45, z), subdiv=1))
    bl = join(bulbs, "Bulbs")
    finish(bl, mat("BulbGlow", C["window"], emission=4.0), "Bulbs")
    export("greenhouse")


def build_tiles():
    # Puzzle pieces: a slab plus one pipe arm, combined by the game per tile.
    reset()
    slab = box("Slab", (0.92, 0.92, 0.16), loc=(0, 0, 0.08))
    finish(slab, mat("Slab", C["slab"]), "Slab", bevel=0.05)
    export("tile_slab")
    reset()
    arm = box("Arm", (0.16, 0.5, 0.12), loc=(0, 0.25, 0.22))
    finish(arm, mat("Pipe", C["pipe"], rough=0.3), "Arm", bevel=0.03)
    export("tile_arm")
    reset()
    hub = cylinder("Hub", 0.13, 0.13, 0.14, verts=12, loc=(0, 0, 0.22))
    finish(hub, mat("Pipe", C["pipe"], rough=0.3), "Hub", bevel=0.02)
    export("tile_hub")


def build_pad():
    reset()
    ring = cylinder("Pad", 0.5, 0.55, 0.12, verts=24, loc=(0, 0, 0.06))
    finish(ring, mat("PadWhite", C["pad"], rough=0.3), "Pad", bevel=0.03)
    export("pad")
    reset()
    gem = sphere("Gem", 0.3, subdiv=1, scale=(1, 1, 0.7))
    finish(gem, mat("GemWhite", C["pad"], emission=0.4, rough=0.25), "Gem")
    export("note")


def build_all():
    print("Building Hourbloom assets with Blender", bpy.app.version_string)
    build_pot()
    build_flower()
    build_glider()
    build_drone()
    build_orb()
    build_sunday()
    build_tower("tower_a", 1.6, 1.6, 6.0, "tower", 1)
    build_tower("tower_b", 2.0, 1.4, 8.5, "tower_b", 2)
    build_tower("tower_c", 1.3, 1.3, 4.5, "tower_c", 3)
    build_greenhouse()
    build_tiles()
    build_pad()
    print("Done ->", GLB_DIR)


if __name__ == "__main__":
    build_all()
