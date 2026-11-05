#!/usr/bin/env python3
"""Open a real stdio MCP session against a server and report whether it works.

Performs initialize -> notifications/initialized -> tools/list, and optionally
calls one read-only tool to prove the server reaches its backend (a server can
complete the handshake while every call fails, e.g. GitHub with a bad token).

Usage:
    probe.py [--timeout SECONDS] [--call TOOL [--call-args JSON]] -- CMD [ARGS...]

Prints one line — "OK <name> <version> | tools=N[ | call TOOL=ok]" or
"FAIL <reason>" followed by the server's stderr tail — and exits 0 / 1.
"""
import argparse
import json
import os
import select
import signal
import subprocess
import sys
import tempfile
import time


def parse_args():
    argv = sys.argv[1:]
    if "--" not in argv:
        sys.exit("usage: probe.py [--timeout S] [--call TOOL [--call-args JSON]] -- CMD [ARGS...]")
    split = argv.index("--")
    parser = argparse.ArgumentParser(prog="probe.py")
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--call", default=None, help="read-only tool to call after tools/list")
    parser.add_argument("--call-args", default="{}", help="JSON object of tool arguments")
    opts = parser.parse_args(argv[:split])
    cmd = argv[split + 1:]
    if not cmd:
        sys.exit("probe.py: missing server command after --")
    return opts, cmd


class Session:
    def __init__(self, cmd):
        # stderr goes to a file, not a pipe: npx leaves a node child that keeps
        # inherited pipes open after the parent dies. A new session lets us kill
        # the whole process group at the end.
        self.errfile = tempfile.TemporaryFile()
        self.proc = subprocess.Popen(
            cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.errfile,
            start_new_session=True,
        )
        self.buf = b""

    def send(self, msg):
        self.proc.stdin.write((json.dumps(msg) + "\n").encode())
        self.proc.stdin.flush()

    def wait_for(self, msg_id, deadline):
        while time.time() < deadline:
            while b"\n" in self.buf:
                line, self.buf = self.buf.split(b"\n", 1)
                try:
                    msg = json.loads(line)
                except ValueError:
                    continue
                if isinstance(msg, dict) and msg.get("id") == msg_id:
                    return msg
            if self.proc.poll() is not None:
                return None
            ready, _, _ = select.select([self.proc.stdout], [], [], 0.5)
            if ready:
                chunk = os.read(self.proc.stdout.fileno(), 65536)
                if not chunk:
                    return None
                self.buf += chunk
        return None

    def close(self):
        try:
            os.killpg(self.proc.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        try:
            self.proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            pass
        self.errfile.seek(0)
        return self.errfile.read().decode(errors="replace")


def main():
    opts, cmd = parse_args()
    deadline = time.time() + opts.timeout
    session = Session(cmd)
    status, detail = "FAIL", ""
    try:
        session.send({
            "jsonrpc": "2.0", "id": 1, "method": "initialize",
            "params": {
                "protocolVersion": "2025-06-18",
                "capabilities": {},
                "clientInfo": {"name": "waffle-mcp-check", "version": "1.0"},
            },
        })
        init = session.wait_for(1, deadline)
        if init is None or "result" not in init:
            detail = "no initialize response" if init is None else "initialize error: " + json.dumps(init.get("error"))[:300]
        else:
            info = init["result"].get("serverInfo", {})
            session.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
            session.send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
            tools = session.wait_for(2, deadline)
            names = [t.get("name") for t in tools["result"].get("tools", [])] if tools and "result" in tools else []
            if not names:
                detail = "tools/list returned nothing"
            else:
                detail = f"{info.get('name', '?')} {info.get('version', '?')} | tools={len(names)}"
                status = "OK"
                if opts.call:
                    if opts.call not in names:
                        status, detail = "FAIL", f"{detail} | tool '{opts.call}' not exposed"
                    else:
                        session.send({
                            "jsonrpc": "2.0", "id": 3, "method": "tools/call",
                            "params": {"name": opts.call, "arguments": json.loads(opts.call_args)},
                        })
                        res = session.wait_for(3, deadline)
                        if res is None:
                            status, detail = "FAIL", f"{detail} | call {opts.call}: no response"
                        elif "error" in res or res.get("result", {}).get("isError"):
                            payload = res.get("error") or res["result"].get("content")
                            status, detail = "FAIL", f"{detail} | call {opts.call}: {json.dumps(payload)[:240]}"
                        else:
                            detail = f"{detail} | call {opts.call}=ok"
    except BrokenPipeError:
        detail = "server exited before the handshake"
    finally:
        stderr = session.close()

    print(f"{status} {detail}")
    if status != "OK":
        tail = [ln for ln in stderr.strip().splitlines() if ln.strip()][-8:]
        for line in tail:
            print(f"    {line[:220]}")
    return 0 if status == "OK" else 1


if __name__ == "__main__":
    sys.exit(main())
