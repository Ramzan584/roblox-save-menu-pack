import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as E
import generate as g


class KitTests(unittest.TestCase):
    def test_variants_and_geometry(self):
        for scale in (.25, 1, 4):
            for palette in g.PALETTES:
                models = g.furniture(scale, palette)
                self.assertEqual(len(models), 6)
                self.assertEqual(sum(map(len, models.values())), 28)
                for parts in models.values():
                    self.assertEqual(len(parts), len({p['name'] for p in parts}))
                    for p in parts:
                        self.assertTrue(all(v > 0 for v in p['size']))
                        self.assertGreaterEqual(p['position'][1]-p['size'][1]/2, -1e-8)

    def test_xml_properties(self):
        root = E.fromstring(g.xml_model(g.furniture()))
        self.assertEqual(root.get('version'), '4')
        nodes = list(root.iter('Item'))
        self.assertEqual(len(nodes), len({n.get('referent') for n in nodes}))
        self.assertEqual({n.get('class') for n in nodes}, {'Model', 'Part'})
        for part in root.findall('.//Item[@class="Part"]'):
            self.assertEqual(part.find('./Properties/bool[@name="Anchored"]').text, 'true')
            self.assertEqual(part.find('./Properties/bool[@name="CanTouch"]').text, 'false')
            self.assertEqual(len(part.findall('./Properties/CoordinateFrame/*')), 12)

    def test_determinism_and_scaled_layout(self):
        raw = g.xml_model(g.furniture(4))
        self.assertEqual(raw, g.xml_model(g.furniture(4)))
        root = E.fromstring(raw)
        # Model bounding boxes do not overlap on the display grid.
        boxes = []
        for model in root.findall('./Item/Item'):
            parts = model.findall('Item')
            bounds = []
            for axis in 'XZ':
                values = [(float(p.find(f'./Properties/CoordinateFrame/{axis}').text),
                           float(p.find(f'./Properties/Vector3/{axis}').text)/2) for p in parts]
                bounds.append((min(c-h for c,h in values), max(c+h for c,h in values)))
            boxes.append(bounds)
        for i,a in enumerate(boxes):
            for b in boxes[i+1:]:
                self.assertTrue(any(a[k][1] < b[k][0] or b[k][1] < a[k][0] for k in range(2)))

    def test_invalid_scales(self):
        for value in (0, -.1, 5, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                g.furniture(value)

    def test_output_and_overwrite(self):
        with tempfile.TemporaryDirectory() as temp:
            out = Path(temp)/'kit'
            manifest = g.generate(out)
            self.assertEqual(manifest['sha256'], hashlib.sha256((out/'SaveLobbyKit.rbxmx').read_bytes()).hexdigest())
            self.assertEqual(json.loads((out/'manifest.json').read_text())['parts'], 28)
            with self.assertRaises(ValueError):
                g.generate(out)


if __name__ == '__main__':
    unittest.main()
