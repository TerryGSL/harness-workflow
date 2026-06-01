#!/usr/bin/env bash
# record.sh — per-requirement 沉淀记录(.harness/records/<id>.md)+ change-index.jsonl。
# 一个需求一个 md(非六件套)。同 commit 关联由证据门强制(见 verify-evidence/ci-gate)。
#   start <type> <slug>  建 record.md(段落骨架+Tasks板+摘最近 index 进 Context)+ 打印 <id>
#   tasks <id>           打印任务进度 X/N done + 各任务行(并行 sub-agent 认领看这里)
#   done  <id>           校验 'Changed & Why'/'Tests' 段非空 + Tasks 无未完成 + append change-index
set -uo pipefail
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
REC="$ROOT/.harness/records"; IDX="$ROOT/.harness/change-index.jsonl"
SDIR="$(cd "$(dirname "$0")" && pwd)"
# state.json 是可删缓存:start/done 自动同步它,不靠"记得手动写"。失败不阻断(它只是缓存)。
sync_state(){ bash "$SDIR/state.sh" set "$1" "$2" >/dev/null 2>&1 || true; }
cmd="${1:-}"; shift 2>/dev/null || true

case "$cmd" in
  start)
    type="${1:-feature}"; slug="${2:-task}"
    id="$(date +%Y%m%d)-$slug"
    mkdir -p "$REC"; f="$REC/$id.md"
    if [ -e "$f" ]; then echo "$id"; exit 0; fi
    {
      echo "# $id"
      echo "Type: $type"
      echo
      echo "## What（解决什么 + 验收）"; echo "<TODO>"; echo
      echo "## Tasks（拆任务 + 进度;并行 sub-agent 各认领一条,标 @owner wt=,文件不相交）"
      echo "- [ ] 1 <第一步>"
      echo "- [ ] 2 <第二步>"; echo
      echo "## Changed & Why（改了什么/为什么）"; echo "<TODO>"; echo
      echo "## Tests（测试/验证）"; echo "<TODO>"; echo
      echo "## Decisions（非显然取舍）"; echo "-"; echo
      echo "## Followups（遗留/下次注意）"; echo "-"; echo
      echo "## Context（最近相关需求,自动摘自 change-index）"
      if [ -f "$IDX" ]; then tail -n 5 "$IDX" | sed 's/^/- /'; else echo "-（无历史）"; fi
    } > "$f"
    sync_state currentTask "$id"; sync_state taskType "$type"; sync_state currentStage in_progress
    echo "$id"
    ;;
  done)
    id="${1:-}"; f="$REC/$id.md"
    [ -f "$f" ] || { echo "✗ record.sh done: 找不到 $f" >&2; exit 1; }
    # 校验关键段落非空非模板(python 解析,robust)
    python3 - "$f" "Changed & Why" "Tests" <<'PY' || exit 1
import sys,re
f=open(sys.argv[1],encoding="utf-8").read()
secs=sys.argv[2:]
parts=re.split(r'(?m)^## ', f)
def body(name):
    for p in parts:
        if p.startswith(name) or p.split('（')[0].strip()==name:
            lines=p.splitlines()[1:]
            txt=[l for l in lines if l.strip() and l.strip() not in ('<TODO>','-')]
            return "\n".join(txt).strip()
    return ""
for s in secs:
    if not body(s):
        sys.stderr.write("✗ record.sh done: '%s' 段为空/未填,补完再 done\n"%s); sys.exit(1)
PY
    type=$(grep -m1 '^Type:' "$f" | sed 's/^Type:[[:space:]]*//')
    one=$(python3 - "$f" <<'PY'
import sys,re
f=open(sys.argv[1],encoding="utf-8").read()
parts=re.split(r'(?m)^## ', f)
for p in parts:
    if p.startswith("What"):
        for l in p.splitlines()[1:]:
            if l.strip() and l.strip() not in ('<TODO>','-'): print(l.strip()); break
        break
PY
)
    python3 -c 'import json,sys; print(json.dumps({"id":sys.argv[1],"type":sys.argv[2],"oneliner":sys.argv[3]},ensure_ascii=False))' "$id" "${type:-?}" "${one:-}" >> "$IDX"
    sync_state currentStage done; sync_state lastGate "record done: $id"
    echo "✓ done: $id → change-index.jsonl appended"
    un=$(grep -c '^- \[ \]' "$f" 2>/dev/null || true); un=${un:-0}
    [ "$un" -gt 0 ] && echo "ℹ 注意:还有 $un 个未勾选任务(Followups 里交代,或下轮继续)" || true
    ;;
  tasks)
    id="${1:-}"; f="$REC/$id.md"
    [ -f "$f" ] || { echo "找不到 $f" >&2; exit 1; }
    dn=$(grep -c '^- \[x\]' "$f" 2>/dev/null || true); tn=$(grep -c '^- \[ \]' "$f" 2>/dev/null || true)
    dn=${dn:-0}; tn=${tn:-0}
    echo "任务进度: $dn/$((dn+tn)) done"
    grep -E '^- \[[ x]\] ' "$f" 2>/dev/null || echo "(无 Tasks)"
    ;;
  *) echo "用法: record.sh start <type> <slug> | tasks <id> | done <id>" >&2; exit 2 ;;
esac
