"""Original CC0 lobby furniture. Python 3.10+, no dependencies or network."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import xml.etree.ElementTree as E

PALETTES = {"forest": ((52, 76, 65), (193, 146, 88), (97, 160, 105)),
            "coast": ((51, 76, 102), (215, 190, 141), (69, 171, 183))}


def furniture(scale=1.0, palette="forest"):
    if not math.isfinite(scale) or not 0.25 <= scale <= 4:
        raise ValueError("scale must be finite and between 0.25 and 4")
    dark, wood, green = PALETTES[palette]
    models = {}

    def add(model, name, size, position, color, collide=True):
        models.setdefault(model, []).append(dict(name=name, size=[v * scale for v in size],
            position=[v * scale for v in position], color=color, collide=collide))

    for name, width in (("BenchShort", 6), ("BenchLong", 10)):
        add(name, "Seat", (width, .4, 2), (0, 2, 0), wood)
        add(name, "Back", (width, 1.6, .3), (0, 3, .85), wood)
        for i, x in enumerate((-width/2+.6, width/2-.6)):
            add(name, f"Leg{i+1}", (.5, 1.8, 1.5), (x, .9, 0), dark)
    for name, width in (("PlanterSquare", 3), ("PlanterWide", 6)):
        add(name, "Pot", (width, 1.8, 3), (0, .9, 0), dark)
        add(name, "Soil", (width-.4, .15, 2.6), (0, 1.85, 0), wood)
        for i, x in enumerate((-width/4, width/4)):
            add(name, f"Foliage{i+1}", (width/2-.2, 1.2, 2.2), (x, 2.5, 0), green, False)
    for i, x in enumerate((-4.5, 4.5)):
        add("Gateway", f"Column{i+1}", (1, 8, 1.5), (x, 4, 0), dark)
        add("Gateway", f"Foot{i+1}", (2, .4, 2.5), (x, .2, 0), wood)
    add("Gateway", "Lintel", (10, 1, 1.5), (0, 8.5, 0), wood)
    add("Gateway", "Accent", (6, .25, 1.6), (0, 8.5, 0), green, False)
    add("Kiosk", "Foot", (3, .3, 2.5), (0, .15, 0), dark)
    add("Kiosk", "Stem", (.7, 2.6, .7), (0, 1.6, 0), dark)
    add("Kiosk", "Board", (3, 2, .4), (0, 3.8, 0), wood)
    for i in range(3):
        add("Kiosk", f"Marker{i+1}", (.35, .35, .15), ((i-1)*.7, 3.8, -.26), green, False)
    return models


def xml_model(models):
    root = E.Element("roblox", version="4")
    E.SubElement(root, "External").text = "null"
    E.SubElement(root, "External").text = "nil"
    serial = 0

    def item(parent, cls, name):
        nonlocal serial
        serial += 1
        node = E.SubElement(parent, "Item", {"class": cls, "referent": f"RBX{serial}"})
        props = E.SubElement(node, "Properties")
        E.SubElement(props, "string", name="Name").text = name
        return node, props

    wrapper, _ = item(root, "Model", "SaveLobbyKit")
    spacing = max(max(p['size'][0] for p in parts) for parts in models.values()) * 1.6
    for i, (name, parts) in enumerate(models.items()):
        model, _ = item(wrapper, "Model", name)
        offset = ((i % 3)*spacing, 0, (i//3)*spacing)
        for part in parts:
            _, p = item(model, "Part", part["name"])
            for key, value in {"Anchored": True, "CanCollide": part["collide"], "CanTouch": False}.items():
                E.SubElement(p, "bool", name=key).text = str(value).lower()
            E.SubElement(p, "token", name="shape").text = "1"
            E.SubElement(p, "token", name="TopSurface").text = "0"
            E.SubElement(p, "token", name="BottomSurface").text = "0"
            size = E.SubElement(p, "Vector3", name="size")
            for axis, v in zip("XYZ", part["size"]):
                E.SubElement(size, axis).text = str(v)
            cf = E.SubElement(p, "CoordinateFrame", name="CFrame")
            for axis, v, off in zip("XYZ", part["position"], offset):
                E.SubElement(cf, axis).text = str(v+off)
            for row in range(3):
                for col in range(3):
                    E.SubElement(cf, f"R{row}{col}").text = str(int(row == col))
            color = E.SubElement(p, "Color3", name="Color")
            for axis, v in zip("RGB", part["color"]):
                E.SubElement(color, axis).text = str(v/255)
    E.indent(root)
    return E.tostring(root, encoding="utf-8", xml_declaration=True)


def generate(output, scale=1, palette="forest"):
    models = furniture(scale, palette)
    if output.exists():
        raise ValueError("Choose a new output directory")
    output.mkdir(parents=True)
    raw = xml_model(models)
    (output / "SaveLobbyKit.rbxmx").write_bytes(raw)
    manifest = {"version": 1, "scale": scale, "palette": palette, "units": "studs",
        "models": {n: len(p) for n, p in models.items()}, "parts": sum(map(len, models.values())),
        "sha256": hashlib.sha256(raw).hexdigest()}
    (output / "manifest.json").write_text(json.dumps(manifest, indent=2)+"\n", encoding="utf-8")
    return manifest


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--scale", type=float, default=1)
    parser.add_argument("--palette", choices=PALETTES, default="forest")
    args = parser.parse_args()
    try:
        print(json.dumps(generate(args.output, args.scale, args.palette), indent=2))
    except (ValueError, OSError) as exc:
        parser.exit(2, f"ERROR: {exc}\n")
