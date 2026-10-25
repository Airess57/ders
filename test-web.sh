
#!/usr/bin/env bash

# Stop if a command fails, a variable is undefined,
# or a pipeline fails.
set -euo pipefail

# Address of the web server.
# BASE_URL can be changed when testing a different server.
BASE_URL="${BASE_URL:-http://127.0.0.1:8000}"

# Execute Python code to send HTTP requests to our web application.
python3 - "$BASE_URL" <<'PYCODE'

import sys
import urllib.error
import urllib.request

# Read the server address passed from the Bash script.
base_url = sys.argv[1]

def check(path, expected_status, expected_text):
    """Send an HTTP request and verify the response."""

    url = base_url + path

    try:
        with urllib.request.urlopen(url, timeout=5) as response:
            status = response.status
            body = response.read().decode("utf-8")

    except urllib.error.HTTPError as error:
        # HTTP errors such as 400 are expected in some tests.
        status = error.code
        body = error.read().decode("utf-8")

    # Verify the HTTP status code.
    if status != expected_status:
        print(f"FAIL: {path}")
        print(f"Expected HTTP status: {expected_status}")
        print(f"Actual HTTP status: {status}")
        sys.exit(1)

    # Verify that the response contains the expected text.
    if expected_text not in body:
        print(f"FAIL: {path}")
        print(f"Expected text: {expected_text}")
        print(f"Actual response: {body}")
        sys.exit(1)

    print(f"PASS: {path}")


print("Running web application tests...")

# Test 1: The health endpoint should report that the server is running.
check("/health", 200, "OK")

# Test 2: The homepage should load successfully.
check("/", 200, "Temperature Analyzer")

# Test 3: Valid temperature readings should return the correct average.
check(
    "/analyze?readings=20%2C25%2C30",
    200,
    "Average: 25.0 C"
)

# Test 4: Invalid input should return HTTP 400 (Bad Request).
check(
    "/analyze?readings=abc",
    400,
    "invalid temperature"
)

print("All web application tests passed!")

PYCODE
