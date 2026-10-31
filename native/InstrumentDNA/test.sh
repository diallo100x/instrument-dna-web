#!/bin/sh
set -eu
cd "$(dirname "$0")"
BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/instrument-dna-test.XXXXXX")
trap 'rm -rf "$BUILD_DIR"' EXIT
${CC:-cc} -std=c11 -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined -fno-omit-frame-pointer -I DSP DSP/DNAKernel.c DSP/DNAPhysical.c Tests/kernel_test.c -lm -pthread -o "$BUILD_DIR/kernel-test"
ASAN_OPTIONS=detect_leaks=0 "$BUILD_DIR/kernel-test"
${CC:-cc} -std=c11 -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined -I DSP DSP/DNAPhysical.c DSP/DNAPhysicalFit.c Tests/physical_fit_test.c -lm -o "$BUILD_DIR/fit-test"
ASAN_OPTIONS=detect_leaks=0 "$BUILD_DIR/fit-test"
${CC:-cc} -std=c11 -Wall -Wextra -Werror -O1 -g -fsanitize=address,undefined -I DSP DSP/DNAPhysical.c Tests/coupled_body_test.c -lm -o "$BUILD_DIR/coupled-test"
ASAN_OPTIONS=detect_leaks=0 "$BUILD_DIR/coupled-test"
python3 Tests/project_test.py
