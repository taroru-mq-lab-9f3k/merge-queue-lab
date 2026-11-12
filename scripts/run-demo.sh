#!/usr/bin/env bash
# マージキューのデモを自動実行する。
# 3 本の PR を作成し、demo-ci の通過後にキューへ入れ、マージまで待つ。
set -euo pipefail

repo="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
base="${BASE:-main}"
count="${COUNT:-3}"
stamp="$(date +%Y%m%d-%H%M%S)"
prs=()

echo "repo:  ${repo}"
echo "base:  ${base}"
echo "count: ${count}"

git switch "${base}"
git pull --ff-only origin "${base}"

for i in $(seq 1 "${count}"); do
  branch="demo/queue-${stamp}-${i}"
  file="demo/${stamp}-${i}.md"

  git switch -c "${branch}" "${base}"
  mkdir -p demo
  printf '# Queue demo %s\n\nGenerated at %s\n' "${i}" "${stamp}" > "${file}"
  git add "${file}"
  git commit -m "キュー確認用の変更 ${i} (${stamp})" >/dev/null
  git push -u origin "${branch}" >/dev/null

  url="$(gh pr create \
    --base "${base}" \
    --head "${branch}" \
    --title "キュー確認用の変更 ${i} (${stamp})" \
    --body "マージキューのグループ確認用の変更です。")"
  number="${url##*/}"
  prs+=("${number}")
  echo "created #${number}: ${url}"

  git switch "${base}" >/dev/null
done

echo
echo "demo-ci の完了を待ちます..."
for n in "${prs[@]}"; do
  state=""
  for _ in $(seq 1 36); do
    state="$(gh pr checks "${n}" --json name,state \
      --jq '.[] | select(.name == "demo-ci") | .state' 2>/dev/null || true)"
    case "${state}" in
      SUCCESS) break ;;
      FAILURE|CANCELLED|SKIPPED)
        echo "#${n} の demo-ci が ${state} で終了しました" >&2
        exit 1
        ;;
    esac
    sleep 5
  done
  if [[ "${state}" != "SUCCESS" ]]; then
    echo "#${n} の demo-ci がタイムアウトしました" >&2
    exit 1
  fi
  echo "#${n} demo-ci: ${state}"
done

echo
echo "キューに投入します..."
for n in "${prs[@]}"; do
  gh pr merge "${n}"
  echo "#${n} をキューに投入"
done

echo
echo "マージを待ちます..."
for _ in $(seq 1 60); do
  remaining=0
  for n in "${prs[@]}"; do
    state="$(gh pr view "${n}" --json state -q .state)"
    if [[ "${state}" != "MERGED" ]]; then
      remaining=$((remaining + 1))
    fi
  done
  if [[ "${remaining}" -eq 0 ]]; then
    echo "すべてマージされました"
    gh pr list --state merged --limit "${count}" \
      --json number,title,mergedAt \
      --jq '.[] | "#\(.number) \(.title) \(.mergedAt)"'
    exit 0
  fi
  sleep 5
done

echo "タイムアウト: 未マージの PR があります" >&2
exit 1
