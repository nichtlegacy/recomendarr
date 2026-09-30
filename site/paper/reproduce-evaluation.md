# Reproducing the September 2026 refresh

The paper's public evidence is [`assets/data/evaluation-v2.json`](./assets/data/evaluation-v2.json).
The raw SQLite snapshots and sampled users' film-level outputs stay private.
You need the same training snapshots, 100 confirmation diaries/libraries, and
frozen movie/source cache to reproduce the published numbers exactly.

The current confirmation database contains the original 2,000 training users
and 100 `diary_users` marked `status='ok', batch='fresh'`. The original-model
replay contains the 500-account snapshot, its original 100 held-out diaries,
and those same 100 fresh users. Neither evaluator receives named case profiles:
that would activate case-seed exclusions and change the training population.
Use the checksums and model replication result in
[`evaluation-provenance.json`](./assets/data/evaluation-provenance.json).

From the repository root, with the project Python environment activated:

```sh
export OPENBLAS_NUM_THREADS=2 PYTHONHASHSEED=0
python scripts/evaluate_holdout.py --ease-db var/paper-refresh/confirmation.sqlite3 \
  --sample-test-users 100 --sample-batch fresh --sample-folds 2 --folds 5 \
  --ease-lambda 2000 --min-year 1985 --max-year 2026 --offline \
  --movie-cache-path var/paper-refresh/movie-cache.sqlite3 \
  --json-out var/paper-refresh/results/holdout-eval-fresh.json
python scripts/evaluate_taste.py --ease-db var/paper-refresh/confirmation.sqlite3 \
  --sample-test-users 100 --sample-batch fresh --sample-folds 2 --folds 5 \
  --ease-lambda 2000 --min-year 1985 --max-year 2026 --offline \
  --movie-cache-path var/paper-refresh/movie-cache.sqlite3 \
  --json-out var/paper-refresh/results/taste-eval-fresh.json
```

Repeat both commands with `previous.sqlite3`, `--ease-lambda 1000`, and output
paths under `var/paper-refresh/previous/`. Run large model evaluations sequentially.
`--offline` aborts on every attempted HTTP request, including soft-failing sources.

The control files `holdout-eval-v2.json`, `taste-eval-v2.json` and
`ease-sample.json` contain the separate development/case run. Export fresh
sample statistics and the paired aggregate, then regenerate figures:

```sh
python scripts/export_ease_sample_stats.py --db var/paper-refresh/confirmation.sqlite3 \
  --batch fresh --movie-cache-path var/paper-refresh/movie-cache.sqlite3 \
  --json-out var/paper-refresh/results/ease-sample-fresh.json
python scripts/export_paper_v2_data.py --raw-dir var/paper-refresh/results \
  --fresh-raw-dir var/paper-refresh/results --previous-raw-dir var/paper-refresh/previous
python scripts/render_paper_assets.py
```

The exporter checks matching people, cutoffs, positives and engine retrieval
before constructing paired intervals. AUC compares the two snapshots on their
shared test-film vocabulary. When rendering HTML with `scripts/picks/paper.py`,
use an explicit `--out` for a review directory; its default targets the site checkout.
