"""Copy into .models/ (next to the downloaded model, venv and hf cache) and run there.
Compute BioCLIP 2.5 text embeddings for extra species, exactly like the
mobile model's own table (s04_build_taxa_table.py): 4 templates per name,
L2-normalized, averaged, re-normalized."""
import json, sys, numpy as np, torch, open_clip
TEMPLATES = ["a photo of {name}.", "a photo of {name}, a type of plant.",
             "a close-up photo of the leaves of {name}.", "a photo of {name} in its natural habitat."]
names = [l.strip() for l in open(sys.argv[1]) if l.strip() and not l.startswith('#')]
model, _, _ = open_clip.create_model_and_transforms("hf-hub:imageomics/bioclip-2.5-vith14")
model.eval(); tok = open_clip.get_tokenizer("hf-hub:imageomics/bioclip-2.5-vith14")
rows = []
with torch.no_grad():
    for n in names:
        f = model.encode_text(tok([t.format(name=n) for t in TEMPLATES]))
        f = f / f.norm(dim=-1, keepdim=True)
        m = f.mean(0); rows.append((m / m.norm()).numpy())
np.save(sys.argv[2], np.stack(rows).astype(np.float32))
json.dump(names, open(sys.argv[2] + '.json', 'w'))
print('done', len(names))
