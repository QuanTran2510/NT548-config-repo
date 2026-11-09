#!/usr/bin/env bash
# Usage:
#   tests/guardrails/run.sh            every bad-*.yaml must be caught, good-*.yaml must pass (server-side dry run: nothing is created)
#   tests/guardrails/run.sh existing   check the Deployments already running (use while the policies are still in Warn mode)
set -uo pipefail
cd "$(dirname "$0")"

if [ "${1:-}" = "existing" ]; then
  bad=0
  for ns in realtime-chat web-api analytics placement-optimiser; do
    for d in $(kubectl -n "$ns" get deploy -o name 2>/dev/null); do
      out=$(kubectl -n "$ns" patch "$d" --dry-run=server --type=merge -p '{"metadata":{"annotations":{"guardrails-check":"1"}}}' 2>&1)
      if echo "$out" | grep -qiE "warning|denied|forbidden"; then
        echo "VIOLATION  $ns/$d"; echo "$out" | sed 's/^/     /'; bad=$((bad + 1))
      else
        echo "ok         $ns/$d"
      fi
    done
  done
  echo "$bad deployment(s) violate the policies"
  [ "$bad" -eq 0 ]; exit $?
fi

blocked=0; warned=0; missed=0; failed_good=0
printf '%-22s %-9s %s\n' "MANIFEST" "RESULT" "POLICY / MESSAGE"
for f in bad-*.yaml; do
  out=$(kubectl apply --dry-run=server -f "$f" 2>&1); rc=$?
  # name of the policy that spoke up ("ValidatingAdmissionPolicy 'guardrail-xxx'"), not any word that starts with guardrail-
  policy=$(echo "$out" | grep -o "ValidatingAdmissionPolicy '[^']*'" | head -1 | cut -d"'" -f2)
  msg=$(echo "$out" | grep -oE "(denied request|binding '[a-z-]*'): .*" | head -1 | sed -E "s/^(denied request|binding '[a-z-]*'): //")
  if [ $rc -ne 0 ] && [ -n "$policy" ]; then r=BLOCKED; blocked=$((blocked + 1))
  elif [ $rc -eq 0 ] && [ -n "$policy" ]; then r=WARNED; warned=$((warned + 1))
  else r=ERROR; missed=$((missed + 1)); policy="-"; msg="not rejected by a policy: ${out:0:110}"; fi
  printf '%-22s %-9s %s: %s\n' "${f%.yaml}" "$r" "${policy:--}" "$msg"
done
for f in good-*.yaml; do
  out=$(kubectl apply --dry-run=server -f "$f" 2>&1); rc=$?
  if [ $rc -eq 0 ] && ! echo "$out" | grep -qi "warning"; then r=PASS; else r=FAIL; failed_good=$((failed_good + 1)); fi
  printf '%-22s %-9s %s\n' "${f%.yaml}" "$r" "$([ "$r" = FAIL ] && echo "${out:0:140}")"
done
echo "blocked=$blocked warned=$warned missed=$missed good_failed=$failed_good (of $(ls bad-*.yaml | wc -l) bad manifests)"
[ "$missed" -eq 0 ] && [ "$failed_good" -eq 0 ]
