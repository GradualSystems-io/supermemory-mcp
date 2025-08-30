#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo .)"

echo "== Security hardening for Supermemory MCP =="

# 1) Remove sensitive logs in app/routes/home.tsx
F="$ROOT/app/routes/home.tsx"
if [[ -f "$F" ]]; then
  cp "$F" "$F.bak"
  perl -0777 -pe 's/^\s*console\.log\(\s*"memories"[^;]*;\s*\n//m;
                  s/^\s*console\.log\(\s*context\.cloudflare\.env\.SUPERMEMORY_API_KEY\s*\);\s*\n//m;' \
    "$F" > "$F.tmp" && mv "$F.tmp" "$F"
  echo "✓ Sanitized logs in app/routes/home.tsx"
fi

# 2) Enforce strong AUTH_SECRET and finite cookie TTL
F="$ROOT/app/session-cookies.server.ts"
if [[ -f "$F" ]]; then
  cp "$F" "$F.bak"
  # Insert AUTH_SECRET check right after the import of createCookieSessionStorage (if not already present)
  if ! grep -q 'AUTH_SECRET must be set to a strong random value' "$F"; then
    perl -0777 -pe 's~(import\s+\{\s*createCookieSessionStorage\s*\}\s+from\s+"react-router"\s*;?\s*)~$1\nconst AUTH_SECRET = process.env.AUTH_SECRET;\nif (!AUTH_SECRET || AUTH_SECRET.length < 32) {\n  throw new Error("AUTH_SECRET must be set to a strong random value");\n}\n~' \
      "$F" > "$F.tmp" && mv "$F.tmp" "$F"
  fi
  # Use AUTH_SECRET in the cookie secrets
  perl -0777 -pe 's/secrets:\s*\[[^\]]*\]/secrets: [AUTH_SECRET]/' \
    "$F" > "$F.tmp" && mv "$F.tmp" "$F"
  # Replace any 'expires: new Date(...)' with a sane TTL (~180 days)
  perl -0777 -pe 's/expires:\s*new Date\([^)]*\)/maxAge: 60 * 60 * 24 * 180/' \
    "$F" > "$F.tmp" && mv "$F.tmp" "$F"
  echo "✓ Hardened cookie settings in app/session-cookies.server.ts"
fi

# 3) Safer CORS (avoid "*" + credentials:true)
# If your code had: cors({ origin: "*", credentials: true })
# we flip credentials to false to avoid the bad combo. (Allowlist upgrade below.)
F="$ROOT/workers/app.ts"
if [[ -f "$F" ]]; then
  cp "$F" "$F.bak"
  perl -0777 -pe 's/cors\(\s*\{\s*origin:\s*"\*"\s*,\s*credentials:\s*true\s*\}\s*\)/cors({ origin: "*", credentials: false })/s' \
    "$F" > "$F.tmp" && mv "$F.tmp" "$F"
  echo "✓ Adjusted CORS in workers/app.ts (credentials:false when origin is \"*\")"
fi

echo "== Done. Review with: git diff =="
