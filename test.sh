
#!/usr/bin/env bash

# Stop the script if a command fails, an undefined variable is used,
# or a command inside a pipeline fails.
set -euo pipefail

# Move to the directory containing this script.
cd "$(dirname "$0")"

# Compile the C program before running tests.
gcc -std=c11 -Wall -Wextra -Werror -O2 monitor.c -o monitor

# Run the C program and compare its output with an expected result.
check() {
    local label="$1"
    local expected="$2"
    shift 2

    # Execute the program with the provided arguments.
    local actual
    actual=$(./monitor "$@")

    # Check whether the output contains the expected text.
    if ! grep -Fq "$expected" <<< "$actual"; then
        echo "FAIL: $label"
        echo "Expected to contain: $expected"
        echo "Actual output:"
        echo "$actual"
        exit 1
    fi

    echo "PASS: $label"
}

echo "Running C application tests..."

# Test 1: Verify the average calculation.
check "basic average" "Average: 25.0 C" 20 25 30

# Test 2: Verify temperatures at or above 30 C are counted.
check "warning count" "Warnings (>= 30 C): 2" 22 31 35

# Test 3: Verify negative temperature values are supported.
check "negative temperatures" "Minimum: -10 C" -10 5

# Test 4: Verify the NORMAL status when all readings are below 30 C.
check "all normal" "Status: NORMAL" 18 20 22

# Test 5: Verify that invalid input is rejected.
# The program should exit with a non-zero exit code.
if ./monitor abc >/dev/null 2>&1; then
    echo "FAIL: invalid input was accepted"
    exit 1
fi

echo "PASS: invalid input rejected"
echo "All C application tests passed!"
