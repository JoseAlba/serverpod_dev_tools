#!/usr/bin/env sh
# Build the Serverpod DevTools Extension web bundle.
set -eu

pkg_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
app_dir="$pkg_dir/devtools_app"
ext_build_dir="$pkg_dir/extension/devtools/build"

echo "==> Building Serverpod DevTools extension web release..."
(cd "$app_dir" && flutter build web --release)

echo "==> Updating Dart DevTools extension web build directory..."
mkdir -p "$ext_build_dir"
rm -rf "$ext_build_dir"/*
cp -R "$app_dir/build/web/"* "$ext_build_dir/"

echo "==> Serverpod DevTools extension built successfully!"
