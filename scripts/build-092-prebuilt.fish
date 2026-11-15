#!/usr/bin/env fish
# Build ONLY a local image; do not modify Compose, start/restart containers,
# update databases, change Docker volumes, or download a Rust toolchain.
# With no argument, downloads the exact known GitHub Actions artifact via gh.
# With an argument, accepts the manually downloaded artifact ZIP or tar.gz.

set -l expected_base "madeofpendletonwool/pinepods:0.9.2"
set -l image_tag "local/rhinepods:pinepods-0.9.2-metadata-43662901995-r3"
set -l run_id "43662901995"
set -l artifact_name "rhinepods-web-pinepods-0.9.2-metadata"
set -l archive_name "rhinepods-web-pinepods-0.9.2.tar.gz"
set -l archive_sha256 "39d86bc9c529ae662367b66529c15c1c91a7e72e44ff93c569002720b430b0b3"
set -l here (realpath (dirname (status filename)))

function fail -a message
    printf 'RhinePods prebuilt frontend: %s\n' "$message" >&2
    exit 1
end

if test (count $argv) -gt 1
    fail "usage: fish scripts/build-092-prebuilt.fish [artifact.zip OR artifact.tar.gz]"
end

for tool in docker tar sha256sum mktemp cp realpath
    command -q "$tool"
    or fail "missing command: $tool"
end

# Fail BEFORE downloading anything if the expected runtime base is absent.
docker image inspect "$expected_base" >/dev/null 2>/dev/null
or fail "Official 0.9.2 base image is not cached. No Docker pull will be attempted."

set -l running_image (docker inspect --format '{{.Config.Image}}' pinepods 2>/dev/null)
# Allow either the original 0.9.2 image or our previous tested r2 overlay.
# Rebuild from the cached official image regardless of which one is live.
if not contains -- "$running_image" "$expected_base" "local/rhinepods:pinepods-0.9.2-metadata-43643575697-perms-r2"
    fail "Unexpected running PinePods image '$running_image'; refusing to proceed."
end

if docker image inspect "$image_tag" >/dev/null 2>/dev/null
    echo "Image already exists: $image_tag. No build needed; no containers changed."
    exit 0
end

set -l workdir (mktemp -d /tmp/rhinepods-092-metadata-XXXXXXXX)
or fail "could not create temporary workspace"
set -l archive "$workdir/$archive_name"

if test (count $argv) -eq 1
    set -l downloaded "$argv[1]"
    test -f "$downloaded"
    or fail "not a file: $downloaded"
    if string match -q '*.zip' -- "$downloaded"
        command -q unzip
        or fail "unzip is required to unpack the downloaded GitHub artifact ZIP"
        unzip -p "$downloaded" "$archive_name" > "$archive"
        or fail "artifact ZIP does not contain $archive_name"
    else if string match -q '*.tar.gz' -- "$downloaded"
        cp "$downloaded" "$archive"
        or fail "could not copy provided archive"
    else
        fail "pass a .zip GitHub artifact or the .tar.gz file inside it"
    end
else
    command -q gh
    or fail "GitHub CLI not found. Download the artifact ZIP in your browser and pass its path instead."
    echo "Downloading only the ~6 MiB compiled frontend from GitHub Actions..."
    gh run download "$run_id" --repo sguzman/RhinePods --name "$artifact_name" --dir "$workdir"
    or fail "GitHub artifact download failed; check gh auth status or use the browser ZIP"
end

# This SHA-256 is from the exact successful 0.9.2 compatibility build logs.
printf '%s  %s\n' "$archive_sha256" "$archive" | sha256sum --check --status
or fail "SHA-256 mismatch: refusing to build an unverified frontend"

mkdir -p "$workdir/dist"
or fail "cannot create dist directory"
tar -xzf "$archive" -C "$workdir/dist"
or fail "failed to extract frontend"
test -s "$workdir/dist/index.html"
or fail "missing index.html in frontend artifact"

cp "$here/Dockerfile.092-prebuilt" "$workdir/Dockerfile"
or fail "could not prepare offline Dockerfile"

echo "Building a local overlay using ONLY the already-cached official 0.9.2 image..."
docker build --pull=false --network=none --tag "$image_tag" "$workdir"
or fail "local Docker overlay failed; running service was not changed"

docker image inspect "$image_tag" >/dev/null
or fail "the local image was not created"

# Frontend smoke test must actually serve HTTP 200, not merely pass API health.
# A previous artifact's index.html had mode 0600 and Nginx served HTTP 403.
echo "Checking Nginx HTML/CSS access in an isolated, no-network container..."
docker run --rm --network none --entrypoint /bin/sh "$image_tag" -ec '
    set -eu
    su-exec nginx:nginx sh -c "test -r /var/www/html/index.html"
    mkdir -p /run/nginx /var/lib/nginx/tmp /var/log/nginx
    chown -R nginx:nginx /run/nginx /var/lib/nginx /var/log/nginx
    nginx -t
    nginx
    curl --fail --silent --show-error --max-time 10 http://127.0.0.1:8040/ -o /tmp/rhinepods-index.html
    test -s /tmp/rhinepods-index.html
    grep -q "<title>Pinepods</title>" /tmp/rhinepods-index.html
    curl --fail --silent --show-error --max-time 10 http://127.0.0.1:8040/static/styles.css -o /dev/null
    echo "PASS: Nginx serves RhinePods HTML and CSS over HTTP"
'
or fail "isolated Nginx HTTP test failed. DO NOT deploy this image"

printf '\nSuccessfully built and HTTP-verified %s\n' "$image_tag"
echo "No running container, Compose config, database, or service was changed."
echo "See docs/RHINEPODS_092_TEST.md for read-only preflight and approval-gated cutover."
