#!/bin/bash

# Simple build script for Taskra
# Usage: ./build.sh [run]

set -e

OUT_DIR="bin"
mkdir -p $OUT_DIR

echo "Building Taskra..."
odin build src -out:$OUT_DIR/taskra -debug

if [ "$1" == "run" ]; then
    echo "Running Taskra..."
    ./$OUT_DIR/taskra
fi
