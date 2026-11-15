#!/usr/bin/env fish
# Fix the confirmed index.html 0600 -> 403 error using the already-built
# RhinePods frontend image. No GitHub artifact downloads or Rust compilation.
# Does not modify any running service. Stops if isolated nginx HTTP test fails.

set -l original "madeofpendletonwool/pinepods:0.9.2"
set -l broken "local/rhinepods:pinepods-0.9.2-metadata-43643575697"
set -l fixed "local/rhinepods:pinepods-0.9.2-metadata-43643575697-perms-r2"
set -l here (realpath (dirname (status filename)))

function abort -a message
    echo "RhinePods frontend repair: $message" >&2
    exit 1
end

for cmd in docker realpath
    command -q $cmd
    or abort "missing $cmd"
end

# Confirm we have not accidentally switched the running image again.
set -l active (docker inspect --format '{{.Config.Image}}' pinepods 2>/dev/null)
test "$active" = "$original"
or abort "running pinepods is '$active', expected '$original'"

# Crucially: the repaired image derives from the locally built test image.
docker image inspect "$broken" >/dev/null 2>/dev/null
or abort "previous test image missing. Do not download a new base image."

echo "Creating permission-repaired image from the existing local image..."
docker build --pull=false --network=none \
    --file "$here/Dockerfile.092-permissions" --tag "$fixed" "$here"
or abort "offline image repair failed"

# Run Nginx independently of the PinePods backend in an isolated, disposable
# container. No host ports, no network access, and no production data mounts.
echo "Testing Nginx access and HTTP response inside the repaired image..."
docker run --rm --network none --entrypoint /bin/sh "$fixed" -ec '
    set -eu
    su-exec nginx:nginx sh -c "test -r /var/www/html/index.html"
    mkdir -p /run/nginx /var/lib/nginx/tmp /var/log/nginx
    chown -R nginx:nginx /run/nginx /var/lib/nginx /var/log/nginx
    nginx -t
    nginx
    curl --fail --silent --show-error --max-time 10 \
      http://127.0.0.1:8040/ -o /tmp/rhinepods-index.html
    test -s /tmp/rhinepods-index.html
    grep -q "<title>Pinepods</title>" /tmp/rhinepods-index.html
    curl --fail --silent --show-error --max-time 10 \
      http://127.0.0.1:8040/static/styles.css -o /dev/null
    echo "PASS: Nginx serves the real RhinePods HTML and CSS over HTTP"
'
or abort "isolated Nginx test failed. DO NOT deploy."

echo "PASS: $fixed"
echo "Production PinePods has NOT been changed."
echo "After explicit cutover, confirm browser page, API and Firefox MPRIS."
