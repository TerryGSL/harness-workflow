#!/usr/bin/env bash
# state.sh — .harness/state.json 唯一读写入口。可删恢复缓存：丢了用 regen 从 git 重建。
# 关键：hooks/CI 绝不读它做 gate；它只为换会话/换工具"秒级恢复"。
# 用法: state.sh show | get <key> | set <key> <value> | regen
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd); F="$ROOT/.harness/state.json"
ensure(){ mkdir -p "$ROOT/.harness"; [ -f "$F" ] || printf '%s\n' '{"currentTask":null,"taskType":null,"currentStage":null,"plan":null,"lastGate":null,"round":0,"updatedAt":null}' > "$F"; }
cmd="${1:-show}"; shift 2>/dev/null || true
case "$cmd" in
  show) ensure; cat "$F" ;;
  get)  ensure; python3 -c 'import json,sys;v=json.load(open(sys.argv[1])).get(sys.argv[2]);print("" if v is None else v)' "$F" "${1:-}" ;;
  set)  ensure; python3 -c 'import json,sys,datetime;f,k,v=sys.argv[1:4];d=json.load(open(f));d[k]=v;d["updatedAt"]=datetime.datetime.now().isoformat(timespec="seconds");json.dump(d,open(f,"w"),ensure_ascii=False,indent=2)' "$F" "${1:-}" "${2:-}" ;;
  regen) ensure; python3 -c '
import json,sys,subprocess,datetime
f=sys.argv[1]
def g(*a):
 try:return subprocess.check_output(["git"]+list(a),text=True,stderr=subprocess.DEVNULL).strip()
 except Exception:return ""
d=json.load(open(f));last=g("log","-1","--format=%s");n=g("rev-list","--count","HEAD")
d["currentTask"]=last or None;d["round"]=int(n) if n.isdigit() else 0;d["lastGate"]="regen from git";d["updatedAt"]=datetime.datetime.now().isoformat(timespec="seconds")
json.dump(d,open(f,"w"),ensure_ascii=False,indent=2);print("regen: currentTask=%r round=%s"%(d["currentTask"],d["round"]))' "$F" ;;
  *) echo "用法: state.sh show|get <k>|set <k> <v>|regen" >&2; exit 2 ;;
esac
