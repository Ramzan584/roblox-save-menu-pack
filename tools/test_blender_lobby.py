import unittest
from pathlib import Path
from blender_lobby import read_models


class ImportTests(unittest.TestCase):
    def test_counts_and_axes(self):
        path=Path(__file__).resolve().parents[1]/'assets/save-lobby/generated/SaveLobbyKit.rbxmx'
        models=read_models(path,.28)
        self.assertEqual(len(models),6)
        self.assertEqual(sum(len(m['parts']) for m in models),28)
        self.assertAlmostEqual(models[1]['bounds_m'][0],2.8)
        for model in models:
            self.assertAlmostEqual(min(p['position'][2]-p['size'][2]/2 for p in model['parts']),0)

    def test_invalid_units(self):
        for units in (0,-1,float('nan'),float('inf')):
            with self.assertRaises(ValueError):
                read_models(Path('unused'),units)


if __name__=='__main__':
    unittest.main()
