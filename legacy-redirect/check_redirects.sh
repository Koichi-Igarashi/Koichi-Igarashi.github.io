#!/usr/bin/env bash
# Verify the redirects of the OLD Quarto Pub site after publishing.
#   bash legacy-redirect/check_redirects.sh
# For every old URL: the page must contain an instant meta refresh and a
# canonical link to the expected new URL, and the new URL must answer 200.
set -u
OLD="${OLD:-https://igapipy.quarto.pub/koichi-igarashi}"
NEW="${NEW:-https://koichi-igarashi.github.io/website}"
fail=0
while read -r old new; do
  html=$(curl -fsSL "$OLD/$old") || { echo "✗ $OLD/$old could not be fetched"; fail=1; continue; }
  if ! grep -q "http-equiv=\"refresh\" content=\"0; url=$NEW/$new\"" <<<"$html"; then
    echo "✗ $OLD/$old: no meta refresh to $NEW/$new"; fail=1; continue
  fi
  if ! grep -q "rel=\"canonical\" href=\"$NEW/$new\"" <<<"$html"; then
    echo "✗ $OLD/$old: no canonical link to $NEW/$new"; fail=1; continue
  fi
  code=$(curl -s -o /dev/null -w "%{http_code}" "$NEW/$new")
  if [ "$code" != "200" ]; then
    echo "✗ $NEW/$new answers $code"; fail=1; continue
  fi
  echo "✓ $OLD/$old -> $NEW/$new"
done <<'LIST'
 
about.html about.html
achievements.html achievements.html
posts.html posts.html
english.html en/
posts/test/ posts/test/
LIST
exit $fail
