# マージキューのデモ

このリポジトリは、GitHub のマージキューを実際に動かすためのラボです。

## 現在の設定

- 対象ブランチ: `main`
- ruleset: `main merge queue`
- 必須チェック: `demo-ci`
- マージ方法: squash
- グループ戦略: `ALLGREEN`
- 最小グループ数: 2
- 最小数待ち: 5 分
- 最大グループ数: 5
- 同時ビルド数: 5

最小グループ数を 2 にしているため、1 本だけキューに入れると最大 5 分待ちます。
グループマージを確認したいときは、2 本以上を続けてキューに入れてください。

## 手動で試す

```bash
# main を最新にする
git switch main
git pull --ff-only origin main

# 1 本目
git switch -c demo/manual-1 main
mkdir -p demo
echo "# demo 1" > demo/manual-1.md
git add demo/manual-1.md
git commit -m "デモ変更 1"
git push -u origin demo/manual-1
gh pr create --base main --head demo/manual-1 --title "デモ変更 1" --body "マージキュー確認用"

# 2 本目
git switch main
git switch -c demo/manual-2 main
echo "# demo 2" > demo/manual-2.md
git add demo/manual-2.md
git commit -m "デモ変更 2"
git push -u origin demo/manual-2
gh pr create --base main --head demo/manual-2 --title "デモ変更 2" --body "マージキュー確認用"

# 必須チェックが通ったらキューに入れる
gh pr merge 1
gh pr merge 2
```

確認ポイント:

- Actions に `merge_group` イベントの実行が現れる
- 実行ブランチが `gh-readonly-queue/main/pr-...` になる
- 2 本が同じタイミングでマージされる
- main のログに PR ごとの squash コミットが積まれる

## 自動で試す

`scripts/run-demo.sh` は、3 本の PR を作成し、チェック通過後にキューへ入れ、マージまで待つ。

```bash
./scripts/run-demo.sh
```

本数を変える場合:

```bash
COUNT=2 ./scripts/run-demo.sh
```

## キュー状態の確認

```bash
gh api graphql -f query='
query {
  repository(owner: "OWNER", name: "REPO") {
    pullRequest(number: 1) {
      number
      state
      mergeQueueEntry { position state enqueuedAt }
    }
  }
}'
```

`mergeQueueEntry.state` は `AWAITING_CHECKS`、`MERGEABLE`、`UNMERGEABLE` などを取る。
キューから外れた場合は `mergeQueueEntry` が `null` になる。
