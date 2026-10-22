# Quarto Pub → GitHub Pages 移行ガイド

ご自身で行う操作（GitHub の設定変更・旧サイトへの公開・Search Console）と，その順番をまとめています．
**順番が重要です：新サイト公開 → 動作確認 → 旧サイトに転送を設置 → Search Console．**

## 0. URL（決定済み）

費用をかけずにできる最も短いURLとして **`https://koichi-igarashi.github.io/`** を採用しています．

| ページ | URL |
|---|---|
| 日本語トップ | `https://koichi-igarashi.github.io/` |
| 日本語 Achievements | `https://koichi-igarashi.github.io/achievements/` |
| 英語トップ | `https://koichi-igarashi.github.io/en/` |
| 英語 Achievements | `https://koichi-igarashi.github.io/en/achievements/` |

このURLにするには **リポジトリ名を `Koichi-Igarashi.github.io` に変更する必要があります**（GitHub の「ユーザーサイト」）．
名前が `website` のままだと `https://koichi-igarashi.github.io/website/` で公開されてしまうため，
ワークフローは URL が一致しない状態での公開を止めるようにしてあります（PR では警告のみ）．

URLを後から変えると検索評価の引き継ぎがもう一度必要になり，旧 Quarto Pub の転送先も2027年以降は変更できません．
独自ドメイン（例 `koichi-igarashi.jp`，有料）にする場合は **転送ページを公開する前に** 決めてください
（`_quarto.yml` の `site-url`，`legacy-redirect/_quarto.yml` の `new-site-url`，`legacy-redirect/check_redirects.sh` の `NEW` を変更し，リポジトリ直下に `CNAME` ファイルを追加）．

## 1. GitHub Pages を有効にする（初回のみ）

1. **リポジトリ名の変更**：GitHub のリポジトリ → **Settings → General → Repository name** を `Koichi-Igarashi.github.io` に変更して *Rename*．
   - 同じ名前のリポジトリが既にある場合は変更できません（その場合はご相談ください）．
   - 旧URL（`github.com/Koichi-Igarashi/website`）は GitHub が自動で転送します．手元のクローンは `git remote set-url origin https://github.com/Koichi-Igarashi/Koichi-Igarashi.github.io.git` で更新できます．
2. この PR を `main` にマージする．
3. **Settings → Pages → Build and deployment → Source** を **「GitHub Actions」** にする．
4. **Actions** タブ → *Build and deploy website* → 最新の実行（または *Run workflow*）が緑になるのを待つ（初回は数分）．
5. `https://koichi-igarashi.github.io/` を開く．

> リポジトリが非公開（private）の場合，無料プランでは GitHub Pages を使えません（公開リポジトリにするか有料プラン）．

## 2. 新サイトの動作確認

公開URLで次を確認します（スマートフォンでも）：

- [ ] 日本語トップ `/` と英語トップ `/en/`，`/achievements/`，`/en/achievements/` が表示される
- [ ] 右上の JP / EN トグルで同じページの別言語版に移動できる
- [ ] Achievements の PDF アイコン・DOI リンク・HUSCAP リンクが開ける
- [ ] Research / Posts は非公開（メニューになく，`/about.html` 等は 404）
- [ ] 存在しないURL（例 `/xxx`）で 404 ページが表示され，メニューのリンクが機能する
- [ ] `/sitemap.xml` に日英両方のページがあり，`/robots.txt` にサイトマップの行がある
- [ ] ページのソース（右クリック→ページのソースを表示）に `canonical`・`hreflang`・`og:` タグがある

自動チェック（`scripts/check_site.R`）は Actions のたびに実行されています．

## 3. Google Search Console に新サイトを登録

1. <https://search.google.com/search-console> → **プロパティを追加** → **URLプレフィックス** に
   `https://koichi-igarashi.github.io/` を入力（github.io ではドメインプロパティは使えません）．
2. 所有権の確認は **HTMLタグ** を選び，表示された `<meta name="google-site-verification" content="XXXX">` の `XXXX` を
   `_quarto.yml` に次のように追加して push します（反映後に「確認」を押す）：

   ```yaml
   format:
     html:
       include-in-header:
         text: '<meta name="google-site-verification" content="XXXX">'
   ```

   （Google Analytics と同じ Google アカウントなら「Google アナリティクス」による確認も可能）
3. 左メニュー **サイトマップ** → `sitemap.xml` を送信．
4. **URL検査** で `https://koichi-igarashi.github.io/` と `https://koichi-igarashi.github.io/en/` を検査し **インデックス登録をリクエスト**．

## 4. 旧 Quarto Pub サイトに転送ページを公開（2026-12-31 まで）

[legacy-redirect/README.md](../legacy-redirect/README.md) の手順に従います．要点：

- 新サイトが表示できることを確認してから行う．
- `cd legacy-redirect && quarto publish quarto-pub`（手元のPCで．Quarto Pub の認証が必要）．
- `bash legacy-redirect/check_redirects.sh` で確認．
- 旧サイトに noindex を付けたり削除したりしない．

## 5. 検索結果の移行を確認する

| 時期 | 確認方法 |
|---|---|
| 公開直後 | Search Console → URL検査で新トップが「URL は Google に登録されています」になるか（数日〜1週間） |
| 1〜4週間 | Google で `site:koichi-igarashi.github.io` を検索し，日英のページが出るか |
| 1〜4週間 | 「五十嵐公一」「Koichi Igarashi」で検索し，新サイトが表示されるか（旧URLと入れ替わる） |
| 継続 | Search Console → **ページ（インデックス作成）** で新ページが「登録済み」になっているか，**検索パフォーマンス** でクリック数が増えるか |
| 任意 | 旧サイトも URL プレフィックス `https://igapipy.quarto.pub/koichi-igarashi/` で登録すると，旧URLが「リダイレクトがあるページ」として処理される様子を確認できます（所有権確認には転送ページへのメタタグ追加が必要：`legacy-redirect/redirect-template.html` の `<head>` に追加して再公開） |

入れ替わりには通常 数週間〜数か月かかります．その間は旧URLが検索結果に残っていても，クリックすると新サイトへ転送されるので問題ありません．

## 6. その後

- Quarto Pub の旧サイトは 2031年末まで残ります．削除は任意で，行う場合も転送公開から1年以上経ってから
  （[legacy-redirect/README.md](../legacy-redirect/README.md)）．
- researchmap，ORCID，Google Scholar，X のプロフィールに載せているウェブサイトURLを新URLに更新してください（被リンクの移行に効果があります）．
- 研究室サイトなど，旧URLにリンクしている外部サイトがあれば更新を依頼すると確実です．

## 参考

- Quarto: [Publishing to GitHub Pages](https://quarto.org/docs/publishing/github-pages.html)
- babelquarto: [Render with CI](https://docs.ropensci.org/babelquarto/articles/render-with-ci.html)（多言語サイトは `quarto publish` を使わず出力フォルダ全体を公開する）
- Google: [Redirects and Google Search](https://developers.google.com/search/docs/crawling-indexing/301-redirects)（0秒の meta refresh は恒久的リダイレクトとして扱われる）
- Google: [Site moves with URL changes](https://developers.google.com/search/docs/crawling-indexing/site-move-with-url-changes)
- Google: [Localized versions of your pages (hreflang)](https://developers.google.com/search/docs/specialty/international/localized-versions)
