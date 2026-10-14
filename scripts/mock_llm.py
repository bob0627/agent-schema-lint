#!/usr/bin/env python3
"""Offline mock of an OpenAI-compatible /chat/completions endpoint.

Used to demo and test `--fix --ai` without a real API key:
    python3 scripts/mock_llm.py &            # listens on 127.0.0.1:18080
    ASL_AI_API_KEY=mock ASL_AI_BASE_URL=http://127.0.0.1:18080 \\
      moon run cmd/main -- --fix --ai --profile deepseek file.json

It echoes back the schema from the request with a placeholder Chinese
description added to every property that lacks one, which is enough to
show the "AI answer -> re-lint -> accept/reject" loop end to end.
"""
import http.server, json, re


def add_descriptions(node):
    if isinstance(node, dict):
        for name, child in (node.get("properties") or {}).items():
            if isinstance(child, dict) and "description" not in child and "$ref" not in child:
                child["description"] = f"{name}（由模型补写的参数说明）"
        for v in node.values():
            add_descriptions(v)
    elif isinstance(node, list):
        for v in node:
            add_descriptions(v)


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def read_body(self):
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            data = b""
            while True:
                size = int(self.rfile.readline().strip(), 16)
                if size == 0:
                    self.rfile.readline()
                    return data
                data += self.rfile.read(size)
                self.rfile.readline()
        return self.rfile.read(int(self.headers.get("Content-Length", 0)))

    def do_POST(self):
        req = json.loads(self.read_body())
        user = req["messages"][-1]["content"]
        schema = json.loads(user[user.index("待修复 schema:\n") + len("待修复 schema:\n"):])
        add_descriptions(schema)
        content = "```json\n" + json.dumps(schema, ensure_ascii=False, indent=2) + "\n```"
        body = json.dumps({"choices": [{"message": {"role": "assistant", "content": content}}]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    http.server.HTTPServer(("127.0.0.1", 18080), Handler).serve_forever()
