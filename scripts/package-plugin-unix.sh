#!/bin/bash
# OpenClaw plugin offline packager for macOS/Linux
# Usage:
#   bash scripts/package-plugin-unix.sh @scope/plugin another-plugin
#   NPM_REGISTRY=https://registry.npmmirror.com bash scripts/package-plugin-unix.sh @scope/plugin@1.2.3
# Requires: Node.js 22+ on the build machine

set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "Usage: bash scripts/package-plugin-unix.sh <plugin-spec> [plugin-spec ...]"
    exit 1
fi

OUTPUT_DIR="${OUTPUT_DIR:-output/plugins}"
BUILD_ROOT="${BUILD_ROOT:-build/plugin-pack}"
NPM_REGISTRY="${NPM_REGISTRY:-https://registry.npmmirror.com}"
SCRIPT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$SCRIPT_ROOT"

OS="$(uname -s)"
ARCH="$(uname -m)"

case "$OS" in
    Darwin) PLATFORM_OS="mac" ;;
    Linux) PLATFORM_OS="linux" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

case "$ARCH" in
    x86_64|amd64) PLATFORM_ARCH="x64" ;;
    aarch64|arm64) PLATFORM_ARCH="arm64" ;;
    armv7l) PLATFORM_ARCH="armv7l" ;;
    *) echo "Unsupported arch: $ARCH"; exit 1 ;;
esac

PLATFORM="${PLATFORM_OS}-${PLATFORM_ARCH}"

echo "=== OpenClaw Plugin Packager ==="
echo "Platform: $PLATFORM"
echo "Registry: $NPM_REGISTRY"
echo ""

NODE_VERSION="$(node --version 2>/dev/null || true)"
if [ -z "$NODE_VERSION" ]; then
    echo "ERROR: Node.js not found. Please install Node.js 22+ first."
    exit 1
fi
echo "Node.js version: $NODE_VERSION"

mkdir -p "$OUTPUT_DIR" "$BUILD_ROOT"

sanitize_name() {
    printf '%s' "$1" | sed 's/^@//; s/[\/@]/-/g; s/[^A-Za-z0-9._-]/-/g'
}

cleanup_plugin_files() {
    local plugin_dir="$1"

    find "$plugin_dir" -type f \( \
        -name "*.ts" -not -name "*.d.ts" -o \
        -name "*.map" -o \
        -name "*.md" -o \
        -name "CHANGELOG*" -o \
        -name "HISTORY*" -o \
        -name "AUTHORS*" -o \
        -name "CONTRIBUTORS*" -o \
        -name ".npmignore" -o \
        -name ".eslintrc*" -o \
        -name ".prettierrc*" -o \
        -name "tsconfig*.json" -o \
        -name "Makefile" -o \
        -name ".editorconfig" -o \
        -name ".travis.yml" \
    \) -delete 2>/dev/null || true

    find "$plugin_dir" -type d \( \
        -name "test" -o \
        -name "tests" -o \
        -name "__tests__" -o \
        -name "spec" -o \
        -name "specs" -o \
        -name "example" -o \
        -name "examples" -o \
        -name ".github" -o \
        -name ".circleci" \
    \) -exec rm -rf {} + 2>/dev/null || true

    rm -f "$plugin_dir/package-lock.json"
}

pack_plugin() {
    local plugin_spec="$1"
    local base_name
    local work_dir
    local pack_output
    local tarball_name
    local tarball_path
    local package_dir
    local plugin_name
    local plugin_version
    local archive_base
    local archive_path
    local checksum_path

    base_name="$(sanitize_name "$plugin_spec")"
    work_dir="$BUILD_ROOT/$base_name"

    rm -rf "$work_dir"
    mkdir -p "$work_dir/dist" "$work_dir/tmp"

    echo ""
    echo "=== Packaging $plugin_spec ==="

    pack_output="$(npm pack "$plugin_spec" --pack-destination "$work_dir/dist" --registry "$NPM_REGISTRY")"
    tarball_name="$(printf '%s\n' "$pack_output" | tail -1)"
    tarball_path="$work_dir/dist/$tarball_name"
    package_dir="$work_dir/package"

    mkdir -p "$package_dir"
    tar -xzf "$tarball_path" -C "$work_dir/tmp"
    mv "$work_dir/tmp/package" "$package_dir"
    rm -rf "$work_dir/tmp"

    if [ ! -f "$package_dir/package.json" ]; then
        echo "ERROR: package.json not found after extracting $tarball_name"
        exit 1
    fi

    pushd "$package_dir" > /dev/null
    npm install \
        --omit=dev \
        --include=optional \
        --install-strategy=nested \
        --registry "$NPM_REGISTRY" \
        2>&1 | tail -10
    popd > /dev/null

    cleanup_plugin_files "$package_dir"

    plugin_name="$(node -e "console.log(require('$package_dir/package.json').name)")"
    plugin_version="$(node -e "console.log(require('$package_dir/package.json').version)")"
    archive_base="$(sanitize_name "$plugin_name")-$plugin_version-$PLATFORM"
    archive_path="$OUTPUT_DIR/$archive_base.tgz"
    checksum_path="$archive_path.sha256"

    tar -czf "$archive_path" -C "$package_dir" .

    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$archive_path" > "$checksum_path"
    else
        shasum -a 256 "$archive_path" > "$checksum_path"
    fi

    echo "Created: $archive_path"
    echo "Checksum: $(cat "$checksum_path")"
}

for plugin_spec in "$@"; do
    pack_plugin "$plugin_spec"
done

echo ""
echo "=== Plugin Packaging Complete ==="
ls -lh "$OUTPUT_DIR"
