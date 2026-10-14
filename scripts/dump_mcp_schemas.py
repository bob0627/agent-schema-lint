import json, subprocess, sys, os
name, cmd = sys.argv[1], sys.argv[2:]
p = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
def send(o): p.stdin.write(json.dumps(o)+"\n"); p.stdin.flush()
def recv(i):
    while True:
        line = p.stdout.readline()
        if not line: raise SystemExit("eof")
        try: m = json.loads(line)
        except: continue
        if m.get("id") == i: return m
send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"asl","version":"0"}}})
init = recv(1)
send({"jsonrpc":"2.0","method":"notifications/initialized"})
send({"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}})
r = recv(2)
p.kill()
os.makedirs(f"schemas/{name}", exist_ok=True)
info = init["result"].get("serverInfo",{})
tools = r["result"]["tools"]
for t in tools:
    json.dump(t["inputSchema"], open(f"schemas/{name}/{t['name']}.json","w"), ensure_ascii=False, indent=2)
print(name, info, len(tools))
