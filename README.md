# Merge Queue Lab

GitHub のマージキューを試すための小さなリポジトリ。

## 構成

- `.github/workflows/demo-ci.yml`: `pull_request` と `merge_group` で起動する CI
- `app.py`: 構文チェック用のサンプルコード
- `main` の ruleset: `demo-ci` を必須チェックにしたマージキュー

## マージキューの確認

1. PR を 2 つ以上作る
2. 必須チェック `demo-ci` を通す
3. 各 PR をキューに入れる
4. Actions の `merge_group` 実行と、PR がまとめてマージされる様子を確認する
