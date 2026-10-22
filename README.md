# Koichi Igarashi — personal website

五十嵐公一の研究者ウェブサイトのソースです．[Quarto](https://quarto.org/) で作成し，
[babelquarto](https://docs.ropensci.org/babelquarto/) で日本語（メイン）・英語の2言語を生成，
GitHub Actions で GitHub Pages に自動公開しています．

- 公開URL: <https://koichi-igarashi.github.io/> （英語版: `/en/`）※リポジトリ名を `Koichi-Igarashi.github.io` にする必要あり（[docs/migration-guide.md](docs/migration-guide.md)）
- 旧サイト（Quarto Pub）: <https://igapipy.quarto.pub/koichi-igarashi/> → 新サイトへ転送（[legacy-redirect/README.md](legacy-redirect/README.md)）
- 移行の経緯・Search Console の手順: [docs/migration-guide.md](docs/migration-guide.md)
- 翻訳のレビュー対象一覧: [docs/translation-review.md](docs/translation-review.md)

## よくある更新作業

すべて **ファイルを編集して `main` に push するだけ** で，数分後にサイトへ反映されます
（GitHub の Actions タブで進行状況を確認できます）．

| やりたいこと | 編集するファイル |
|---|---|
| ニュースを追加 | `data/cv.yml` の `news:` の先頭に1項目追加（`ja` と `en`） |
| 論文を追加・更新 | `data/publications.yml`（下記） |
| 助成・受賞・発表を追加 | `data/cv.yml` の `grants:` / `awards:` / `presentations:` |
| 被引用数を更新 | `Rscript scripts/update_citations.R`（または `data/citations.yml` を手で編集） |
| Research / Posts ページを公開する | 現在は非公開（ソースは `about*.qmd`, `posts*.qmd`, `posts/` に保存）．`_quarto.yml` の `render:` の除外行を消し，`_quarto-ja.yml` / `_quarto-en.yml` のメニューに追加，`scripts/check_site.R` の `unpublished_pages` を更新 |
| メニュー（ナビバー） | `_quarto-ja.yml`（日本語版）と `_quarto-en.yml`（英語版） |
| サイト共通の説明文・URL | `_quarto.yml` |

### 論文の追加（`data/publications.yml`）

日英どちらのページもこの1ファイルから生成されます．出版年の新しい順に自動で並びます．

```yaml
  - id: igarashi2027xxx            # 任意の一意な名前（被引用数の対応付けに使用）
    year: 2027
    authors: [K Igarashi, S Wada]  # "K Igarashi" は自動で太字
    title: "Title with *Scientific name* in italics"
    journal: "Journal name"
    volume: "12"
    issue: "3"
    pages: "45-67"                 # または article: "e123"
    status: "Accepted"             # 出版済みなら削除
    doi: "10.xxxx/xxxxx"           # タイトルと DOI 表示がリンクになる
    pdf:                           # 1つ目が PDF アイコン，2つ目以降は本文下にリンク表示
      - url: "papers/Journal_Igarashi_2027.pdf"   # リポジトリ内のファイル
        label: "Accepted manuscript"
      - url: "https://eprints.lib.hokudai.ac.jp/..."  # 機関リポジトリ・出版社・ResearchGate など外部URLも可
        label: "HUSCAP"
    links:                         # データ・コードなど（任意）
      - url: "https://doi.org/10.5281/zenodo.xxxxx"
        label: "Data & code (Zenodo)"
```

- PDF をリポジトリに置く場合は `papers/` に保存します（置かずに外部URLだけでも構いません）．
- 出版社の規定上，公開できる版（著者最終稿など）か確認してください．

### ニュース・業績（`data/cv.yml`）

```yaml
news:
  - date: 2027-01-10
    ja: "〇〇に論文がアクセプトされました．"
    en: "My paper was accepted in ○○."   # 省略すると英語版には表示されません
```

日付の新しい順に自動で並び，番号も自動で振られます．Markdown（`**太字**`, `*斜体*`）が使えます．

## ローカルでのビルド・プレビュー

### 必要なもの（バージョンは固定しています）

| ツール | バージョン | 備考 |
|---|---|---|
| [Quarto](https://quarto.org/docs/get-started/) | 1.10.19 | `.github/workflows/publish.yml` の `QUARTO_VERSION` |
| [R](https://cran.r-project.org/) | 4.6.1 | 同 `R_VERSION`（4.5 以降なら概ね可） |
| R パッケージ | 2026-10-01 時点の CRAN スナップショット | `scripts/install_deps.R` が導入 |
| babelquarto | GitHub の固定コミット | 同上 |

初回のみ：

```sh
Rscript scripts/install_deps.R
```

### 片方の言語だけ素早く確認（編集中のおすすめ）

```sh
quarto preview --profile ja    # 日本語ページ（英語版・言語切替リンクは表示されません）
```

英語ページは `*.en.qmd` を一時的に確認したい場合も，下の「完全ビルド」を使ってください．

### 日英両方を含む完全ビルド（公開されるものと同じ）

```sh
Rscript scripts/build.R --local
python3 -m http.server 4321 -d _site    # → http://localhost:4321/
Rscript scripts/check_site.R --local    # リンク切れ・SEOタグなどの自動チェック
```

本番と同じURL設定でビルドする場合は `Rscript scripts/build.R` → `Rscript scripts/check_site.R`（どちらも `--local` なし）．
チェックでは，ページ・リンク・画像・PDF・canonical・hreflang・言語切替・サイトマップ・robots.txt を検査します．

> **macOS / Linux で文字化けやエラーが出る場合**：ロケールが UTF-8 か確認してください（`export LANG=ja_JP.UTF-8` など）．

## 仕組み

```
index.qmd        日本語トップ（/）          index.en.qmd  英語トップ（/en/）
achievements/index.qmd  （/achievements/）  achievements/index.en.qmd （/en/achievements/）
                 ※ 英語版は同じ場所に name.en.qmd を置く（ファイル名で日英が対応）
                 ※ ページを増やすときは フォルダ/index.qmd にすると URL が /フォルダ/ になる
_quarto.yml      共通設定（サイトURL・テーマ・babelquarto の設定）
_quarto-ja.yml   日本語版のメニュー     ← ナビバーは必ずこちらに書く
_quarto-en.yml   英語版のメニュー       （_quarto.yml に書くと日英が重複表示される）
data/            論文・ニュース・業績・プロフィール（日英共通のデータ）
R/               データから表・リストを作る R コード
scripts/
  build.R            ビルド本体（babelquarto → 後処理）
  postprocess_site.R canonical, hreflang, og:url, JP/EN トグル, JSON-LD, sitemap.xml, robots.txt
  check_site.R       生成サイトの自動チェック（CI でも実行）
  install_deps.R     R パッケージの導入（バージョン固定）
  update_citations.R Google Scholar から被引用数を取得（任意・手動）
legacy-redirect/  旧 Quarto Pub サイトに置く転送ページ
papers/           サイトで公開する PDF
images/           画像（images/web/ がサイト用に圧縮済み．images/ 直下の元写真は公開されません）
```

### デプロイ（GitHub Actions）

`.github/workflows/publish.yml`

- `main` への push → URL確認 → ビルド → チェック → GitHub Pages へ公開
  （`_quarto.yml` の `site-url` とリポジトリの公開URLが一致しないと公開を止めます）
- プルリクエスト → ビルドとチェックのみ（公開しない）．生成サイトは Artifacts からダウンロード可
- 手動実行: Actions タブ → *Build and deploy website* → *Run workflow*

babelquarto のドキュメントにある通り，多言語サイトは `quarto publish` では英語版が公開されないため，
GitHub 公式の Pages アクション（`upload-pages-artifact` / `deploy-pages`）で `_site/` 全体を公開しています．

### サイトURLを変えるとき

`_quarto.yml` の `website: site-url:` と `legacy-redirect/_quarto.yml` の `new-site-url:` を同じ値に変更します
（独自ドメインの場合は `CNAME` ファイルも追加）．詳しくは [docs/migration-guide.md](docs/migration-guide.md)．

## トラブルシューティング

| 症状 | 対処 |
|---|---|
| Actions のビルドが R パッケージの導入で失敗 | `scripts/install_deps.R` の `cran_snapshot` を新しい日付にして再実行 |
| 英語版のメニューに日本語の項目が混ざる | ナビバーを `_quarto.yml` に書いていないか確認（`_quarto-ja.yml` / `_quarto-en.yml` に書く） |
| 英語ページが生成されない | ファイル名が `name.en.qmd` になっているか，日本語の `name.qmd` があるか確認 |
| `check_site.R` がエラー | 表示されたページ・リンクを修正（リンク切れ，翻訳ページの欠落など） |
