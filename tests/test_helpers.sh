#!/bin/sh
# @file tests/test_helpers.sh
# @description Shared test utilities for ephemeral TCP port allocation, server readiness polling, and safe process cleanup.

# allocate_free_port finds and prints an available local TCP port in the ephemeral range.
# @param $1: fallback_port - Optional starting port number if python3/awk socket probing is unavailable (default: 18100).
# @return Prints an unused TCP port number to stdout.
allocate_free_port() {
	_base_port="${1:-18100}"
	if command -v python3 >/dev/null 2>&1; then
		python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1]); s.close()' 2>/dev/null && return 0
	fi
	_cand=$((_base_port + ($$ % 1000)))
	while lsof -i :"${_cand}" >/dev/null 2>&1; do
		_cand=$((_cand + 1))
	done
	printf '%s\n' "${_cand}"
}

# wait_for_port polls a local TCP port until it accepts connections or times out.
# @param $1: port - The TCP port number on 127.0.0.1 to poll.
# @param $2: max_attempts - Optional maximum number of 100ms polling attempts (default: 50).
# @return Returns 0 when the port is listening, or 1 on timeout.
wait_for_port() {
	_wait_port="$1"
	_max_tries="${2:-50}"
	_try=0
	while [ "${_try}" -lt "${_max_tries}" ]; do
		if command -v nc >/dev/null 2>&1 && nc -z 127.0.0.1 "${_wait_port}" >/dev/null 2>&1; then
			return 0
		elif command -v lsof >/dev/null 2>&1 && lsof -i :"${_wait_port}" >/dev/null 2>&1; then
			return 0
		elif curl -s --max-time 1 "http://127.0.0.1:${_wait_port}/" >/dev/null 2>&1; then
			return 0
		fi
		sleep 0.1 2>/dev/null || sleep 1
		_try=$((_try + 1))
	done
	return 1
}

# cleanup_server_pid safely terminates a background server process and any child listeners on its port.
# @param $1: server_pid - Process ID of the background server.
# @param $2: port - Optional TCP port to release if child processes remain bound.
# @return Returns 0.
cleanup_server_pid() {
	_srv_pid="${1:-}"
	_srv_port="${2:-}"
	if [ -n "${_srv_pid}" ]; then
		pkill -P "${_srv_pid}" 2>/dev/null || true
		kill "${_srv_pid}" 2>/dev/null || true
	fi
	if [ -n "${_srv_port}" ] && command -v lsof >/dev/null 2>&1; then
		_port_pids=$(lsof -t -i :"${_srv_port}" 2>/dev/null || true)
		if [ -n "${_port_pids}" ]; then
			# shellcheck disable=SC2086
			kill ${_port_pids} 2>/dev/null || true
		fi
	fi
	return 0
}
