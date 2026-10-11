"""Copy into .models/ (next to the downloaded model, venv and hf cache) and run there.
Builds the on-device lookup table for the plants in assets/plants/plants.json.
Rows come from the mobile model's own table when the species is there, and are
computed with BioCLIP 2.5's text tower (same 4 templates) when it is missing."""
import json, subprocess, sys, numpy as np, os
here = os.path.dirname(os.path.abspath(__file__))
plants = json.load(open(os.path.join(here, '../assets/plants/plants.json')))
T = np.load(os.path.join(here, 'bioclip/taxa_table.npy'))
L = [x['scientific'] for x in json.load(open(os.path.join(here, 'bioclip/taxa_labels.json')))]
have = {n: T[i] for i, n in enumerate(L)}
E = np.load(os.path.join(here, 'extra.npy')); N = json.load(open(os.path.join(here, 'extra.npy.json')))
have.update({n: E[i] for i, n in enumerate(N)})
pairs = [(p['id'], n) for p in plants for n in [p['scientific'], *p.get('also_matches', [])]]
missing = sorted({n for _, n in pairs if n not in have})
if missing:
    open(os.path.join(here, 'missing.txt'), 'w').write('\n'.join(missing))
    subprocess.run([os.path.join(here, 'venv/bin/python'), os.path.join(here, 'embed_taxa.py'),
                    os.path.join(here, 'missing.txt'), os.path.join(here, 'missing.npy')],
                   check=True, env={**os.environ, 'HF_HOME': os.path.join(here, 'hf')})
    M = np.load(os.path.join(here, 'missing.npy'))
    have.update({n: M[i] for i, n in enumerate(missing)})
rows = np.stack([have[n] for _, n in pairs]).astype('<f4')
out = os.path.join(here, '../assets/plants')
rows.tofile(os.path.join(out, 'table_f32.bin'))
open(os.path.join(out, 'table_ids.txt'), 'w').write('\n'.join(i for i, _ in pairs) + '\n')
print(f'{len(plants)} plants, {len(pairs)} rows, {len(missing)} computed with BioCLIP 2.5: {missing}')
