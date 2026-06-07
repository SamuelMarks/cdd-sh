#!/bin/sh
set -eu

# Generate the Server
rm -rf tests/out
mkdir -p tests/out
./bin/cdd-sh from_openapi to_sdk_cli -i tests/test.json -o tests/out
./bin/cdd-sh from_openapi to_server -i tests/test.json -o tests/out

if [ ! -f tests/out/src/server.sh ]; then
	echo "FAIL: server.sh not generated"
	exit 1
fi

cat <<'MOCK' >tests/out/src/server_mock_test.py
import subprocess
import threading
import time
import requests
import sys

def run_server():
    import os
    env = os.environ.copy()
    env["PORT"] = "8101"
    global server_process
    server_process = subprocess.Popen(["sh", "tests/out/src/server.sh"], env=env)

threading.Thread(target=run_server, daemon=True).start()
time.sleep(2) # Give nc more time to start up

try:
    s = requests.Session()
    resp = s.post("http://localhost:8101/mcp/message", json={"jsonrpc":"2.0","id":1,"method":"initialize"}, timeout=2)
    if "protocolVersion" not in resp.text:
        print("FAIL: Server initialize: " + resp.text)
        sys.exit(1)

    time.sleep(0.5)
    s = requests.Session() # new session because nc kills pipe
    try:
        resp = s.post("http://localhost:8101/mcp/message", json={"jsonrpc":"2.0","method":"notifications/initialized"}, timeout=2)
        if resp.status_code != 200:
            print("FAIL: Server initialized ack: " + resp.text)
            sys.exit(1)
    except requests.exceptions.ReadTimeout:
        pass
    except requests.exceptions.ConnectionError:
        pass

    time.sleep(0.5)
    s = requests.Session() # new session
    resp = s.post("http://localhost:8101/mcp/message", json={"jsonrpc":"2.0","id":2,"method":"tools/list"}, timeout=2)
    if "genull_nullsers" not in resp.text:
        print("FAIL: Server tools/list")
        sys.exit(1)

    time.sleep(0.5)
    s = requests.Session()
    resp = s.post("http://localhost:8101/mcp/message", headers={"Authorization": "Bearer my-test-token"}, json={"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"genull_nullsers","arguments":{}}}, timeout=2)
    if "content" not in resp.text and "isError" not in resp.text:
        print("FAIL: Server tools/call")
        sys.exit(1)

    time.sleep(0.5)
    s = requests.Session()
    resp = s.post("http://localhost:8101/mcp/message", json={"jsonrpc":"2.0","id":4,"method":"resources/list"}, timeout=2)
    if "resources" not in resp.text:
        print("FAIL: Server resources/list")
        sys.exit(1)

    time.sleep(0.5)
    s = requests.Session()
    resp = s.post("http://localhost:8101/mcp/message", json={"jsonrpc":"2.0","id":5,"method":"roots/list"}, timeout=2)
    if "roots" not in resp.text:
        print("FAIL: Server roots/list")
        sys.exit(1)

    time.sleep(0.5)
    s = requests.Session()
    resp = s.post("http://localhost:8101/mcp/message", json={"jsonrpc":"2.0","id":6,"method":"ping"}, timeout=2)
    if "result" not in resp.text:
        print("FAIL: Server ping")
        sys.exit(1)

    time.sleep(0.5)
    s = requests.Session()
    try:
        resp = s.post("http://localhost:8101/mcp/message", json={"jsonrpc":"2.0","method":"notifications/message","params":{"level":"info","data":"test log"}}, timeout=2)
    except requests.exceptions.ReadTimeout:
        pass
    except requests.exceptions.ConnectionError:
        pass

    print("Server generation test passed!")

except Exception as e:
    print(f"FAIL: Request failed - {e}")
    sys.exit(1)
finally:
    if 'server_process' in globals():
        server_process.kill()
    import subprocess
    subprocess.run(["pkill", "-f", "cdd_sse_"], check=False)
MOCK

python3 tests/out/src/server_mock_test.py || exit 1
