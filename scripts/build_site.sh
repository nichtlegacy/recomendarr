#!/usr/bin/env bash
# Assemble the site into _site/ for GitHub Pages.
#
# main holds the shell (landing, 404, stylesheet). The personal pages under
# u/ come from the orphan `picks` branch, which the generator in the private
# recomendarr repo force-pushes as one commit, so removing a page removes it
# from history too. The workflow checks that branch out into picks/; locally
# the generator writes straight into the gitignored picks/ folder.
#
#   scripts/build_site.sh            # build _site/
#   scripts/build_site.sh --serve    # build, then serve on 0.0.0.0:8000
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$ROOT/_site"

# Full W3C datetime: Google reads <lastmod> for scheduling, date-only is coarser.
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%S+00:00)"

# Cookieless, self-hosted Umami. The pages on main carry this tag in their
# <head>; the personal pages come from the private generator and get it here.
UMAMI_TAG='<script defer src="https://insights.nichtlegacy.com/v.js" data-website-id="7a140aa1-9f8a-4378-9619-6e76a9bb376e" data-domains="recomendarr.nichtlegacy.com"></script>'

# Empty the folder rather than replacing it, so a --serve already running from
# it keeps serving and picks up the new files.
mkdir -p "$OUT"
find "$OUT" -mindepth 1 -delete

cp "$ROOT"/site/app.css "$ROOT"/site/robots.txt "$ROOT"/site/site.webmanifest "$ROOT"/site/og.png \
   "$ROOT"/site/icon.svg "$ROOT"/site/favicon.ico "$ROOT"/site/apple-touch-icon.png \
   "$ROOT"/site/icon-192.png "$ROOT"/site/icon-512.png "$OUT/"
[ -f "$ROOT/site/CNAME" ] && cp "$ROOT/site/CNAME" "$OUT/"

# Pages caches for ten minutes: a new build must never share a stylesheet URL
# with an old one. Every page links app.css, the personal ones as ../../app.css.
CSS_V="$(shasum -a 256 "$ROOT/site/app.css" | cut -c1-8)"
# Link previews are cached by Discord, Reddit and co. for days: a new image needs a new URL.
OG_V="$(shasum -a 256 "$ROOT/site/og.png" | cut -c1-8)"
# In-place edit that works with GNU and BSD sed alike.
bust() { for f in "$@"; do sed "s|app\.css\"|app.css?v=$CSS_V\"|" "$f" > "$f.tmp" && mv "$f.tmp" "$f"; done; }
# paper/ also carries the raw Markdown and its assets (from scripts/picks/paper.py).
cp -R "$ROOT/site/paper" "$OUT/paper"
for page in index.html 404.html paper/index.html; do
  sed -e "s|__BUILD_DATE__|$BUILD_DATE|g" -e "s|__OG_V__|$OG_V|g" "$ROOT/site/$page" > "$OUT/$page"
  bust "$OUT/$page"
done
sed "s|__BUILD_DATE__|$BUILD_DATE|g" "$ROOT/site/sitemap.xml" > "$OUT/sitemap.xml"

pages=0
if [ -d "$ROOT/picks/u" ]; then
  mkdir -p "$OUT/u"
  cp -R "$ROOT"/picks/u/. "$OUT/u/"
  # picks.json is the generator's re-render source, not something to serve.
  find "$OUT/u" -name picks.json -delete
  while IFS= read -r page; do
    # Older generated pages still carry the public request navigation/footer.
    # Normalize the published copy so private re-renders keep the showcase nav.
    sed -e '/class="nav-item".*>Get yours<\/a>/d' \
        -e '/<p>Want a page removed?/d' \
        -e 's|</svg>Picks</a>|</svg>Pics</a>|g' \
        -e 's|</svg>How it works</a>|</svg>How It Works</a>|g' \
        "$page" > "$page.tmp"
    mv "$page.tmp" "$page"
    if ! grep -q 'insights\.nichtlegacy\.com/v\.js' "$page"; then
      awk -v tag="$UMAMI_TAG" '!done && /<\/head>/ { sub(/<\/head>/, tag "\n</head>"); done = 1 } 1' \
        "$page" > "$page.tmp"
      mv "$page.tmp" "$page"
    fi
    bust "$page"
  done < <(find "$OUT/u" -name index.html)
  pages="$(find "$OUT/u" -mindepth 2 -maxdepth 2 -name index.html | wc -l | tr -d ' ')"
fi

# Any placeholder left behind would ship to production, so fail loudly instead.
if grep -rq "__BUILD_DATE__\|__OG_V__\|{{[A-Z_]*}}" "$OUT"; then
  echo "unsubstituted placeholder left in _site" >&2
  exit 1
fi

# Every page Pages serves should be counted; one without the tag is a gap nobody notices.
untagged="$(find "$OUT" -name '*.html' -exec grep -L 'insights\.nichtlegacy\.com/v\.js' {} + || true)"
if [ -n "$untagged" ]; then
  echo "page without the Umami tag:" >&2
  echo "$untagged" | sed "s|^$OUT/|  |" >&2
  exit 1
fi

# A file referenced but never copied would 404 in production, where nobody looks.
# 404.html resolves from the site root (<base href="/">), the others from their folder.
missing=0
for page in index.html 404.html paper/index.html; do
  base="$(dirname "$page")"; [ "$page" = 404.html ] && base=.
  while read -r ref; do
    [ -z "$ref" ] && continue
    case "$ref" in /*) path="${ref#/}" ;; *) path="$base/$ref" ;; esac
    path="$(python3 -c 'import os,sys; print(os.path.normpath(sys.argv[1]))' "$path")"
    # Without personal pages (e.g. before the first deploy), links into u/ can't resolve.
    case "$path" in u/*) [ "$pages" -eq 0 ] && continue ;; esac
    [ -e "$OUT/$path" ] && { [ -f "$OUT/$path" ] || [ -f "$OUT/$path/index.html" ]; } \
      || { echo "referenced but missing in $page: $ref" >&2; missing=1; }
  done < <(grep -o '\(src\|href\)="[^":#]*"' "$OUT/$page" | sed 's/.*="//; s/"$//; s/?.*$//' | grep -v '^$' | sort -u)
done
for page in "$OUT"/u/*/index.html; do
  [ -f "$page" ] || continue
  dir="$(dirname "$page")"
  csv="$(grep -o 'href="[^"]*\.csv"' "$page" | head -1 | sed 's/href="//; s/"$//' || true)"
  [ -n "$csv" ] || { echo "no list file linked: ${page#"$OUT"/}" >&2; missing=1; continue; }
  [ -f "$dir/$csv" ] || { echo "list file missing: ${dir#"$OUT"/}/$csv" >&2; missing=1; }
done
[ "$missing" -eq 0 ] || exit 1

echo "built _site with $pages personal page(s) ($(du -sh "$OUT" | cut -f1))"

if [ "${1:-}" = "--serve" ]; then
  port="${2:-8000}"
  echo "serving on http://0.0.0.0:$port"
  cd "$OUT"
  # no-cache: the browser may keep files but must ask before reusing them,
  # so a rebuild shows up on a plain reload.
  exec python3 - "$port" <<'PY'
import http.server, sys

class Handler(http.server.SimpleHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def end_headers(self):
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, *args):
        pass

class Server(http.server.ThreadingHTTPServer):
    # socketserver's default backlog of 5 drops a browser's parallel requests.
    request_queue_size = 128
    daemon_threads = True

Server(("0.0.0.0", int(sys.argv[1])), Handler).serve_forever()
PY
fi
