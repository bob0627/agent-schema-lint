#!/usr/bin/env python3
"""Lint (and --fix) every schema under cases/mcp-servers with every profile.

Usage: python3 scripts/run_cases.py [path/to/main.exe]
Writes cases/results.json and prints the summary tables used in docs/CASES.md.
"""
import collections, glob, json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
    ROOT, "_build/native/debug/build/cmd/main/main.exe")
PROFILES = ["generic", "deepseek", "kimi", "qwen", "glm"]
files = sorted(glob.glob(os.path.join(ROOT, "cases/mcp-servers/*/*.json")))
res = {}
for f in files:
    key = os.path.relpath(f, ROOT)
    res[key] = {}
    for p in PROFILES:
        out = subprocess.run([BIN, "--format", "json", "--profile", p, f],
                             capture_output=True, text=True).stdout
        diags = json.loads(out)
        fixed = subprocess.run([BIN, "--fix", "--profile", p, f],
                               capture_output=True, text=True)
        after = subprocess.run([BIN, "--format", "json", "--profile", p, "/dev/stdin"],
                               input=fixed.stdout, capture_output=True, text=True).stdout
        res[key][p] = {"before": diags, "after_fix": json.loads(after)}
json.dump(res, open(os.path.join(ROOT, "cases/results.json"), "w"), ensure_ascii=False, indent=1)

def has_err(ds): return any(d["severity"] == "error" for d in ds)
print(f"schemas: {len(res)}")
print("| profile | 有 error 的 schema | --fix 后仍有 error | warning 总数（前→后） |")
print("| --- | --- | --- | --- |")
for p in PROFILES:
    b = sum(has_err(r[p]["before"]) for r in res.values())
    a = sum(has_err(r[p]["after_fix"]) for r in res.values())
    wb = sum(d["severity"] == "warning" for r in res.values() for d in r[p]["before"])
    wa = sum(d["severity"] == "warning" for r in res.values() for d in r[p]["after_fix"])
    print(f"| {p} | {b}/{len(res)} | {a}/{len(res)} | {wb} → {wa} |")
print()
servers = sorted({k.split('/')[2] for k in res})
print("| server | tools | " + " | ".join(PROFILES) + " |")
print("| --- | --- | " + " | ".join("---" for _ in PROFILES) + " |")
for s in servers:
    ks = [k for k in res if k.split('/')[2] == s]
    cells = [str(sum(has_err(res[k][p]["before"]) for k in ks)) for p in PROFILES]
    print(f"| {s} | {len(ks)} | " + " | ".join(cells) + " |")
print()
for p in PROFILES:
    c = collections.Counter(d["code"] for r in res.values() for d in r[p]["before"])
    print(p, dict(sorted(c.items())))
left = collections.Counter((p, d["code"], d["message"][:60]) for r in res.values() for p in PROFILES for d in r[p]["after_fix"] if d["severity"] == "error")
for k, v in left.most_common(): print("left", v, k)
