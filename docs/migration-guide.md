# Quarto Pub → GitHub Pages 移行ガイド

ご自身で行う操作（GitHub の設定変更・旧サイトへの公開・Search Console）と，その順番をまとめています．
**順番が重要です：新サイト公開 → 動作確認 → 旧サイトに転送を設置 → Search Console．**

## 0. 公開前に決めること：最終的なURL

URLを後から変えると検索評価の引き継ぎがもう一度必要になり，旧 Quarto Pub の転送先も
2027年以降は変更できません．**転送ページを公開する前に** 最終URLを決めてください．

| 案 | URL | 必要な操作 | 評価 |
|---|---|---|---|
| A（現状のまま・既定） | `https://koichi-igarashi.github.io/website/` | なし | すぐ公開できる．ただしサブパスのため `robots.txt` は検索エンジンに読まれない（サイトマップは Search Console から送信すれば問題なし） |
| B | `https://koichi-igarashi.github.io/` | リポジトリ名を `koichi-igarashi.github.io` に変更（同名リポジトリが既にあれば不可） | URLが短く，robots.txt も有効．おすすめ |
| C | 独自ドメイン（例 `https://koichi-igarashi.jp/`） | ドメイン取得・DNS 設定・`CNAME` ファイル | 将来ホスティングを変えてもURLが変わらない．費用がかかる |

B または C にする場合は，`_quarto.yml` の `site-url` と `legacy-redirect/_quarto.yml` の `new-site-url`，
`legacy-redirect/check_redirects.sh` の `NEW` を新しいURLに変更します（C は加えてリポジトリ直下に `CNAME` ファイル）．
この PR は案 A で実装しています．

## 1. GitHub Pages を有効にする（初回のみ）

1. この PR を `main` にマージする．
2. GitHub のリポジトリ → **Settings → Pages → Build and deployment → Source** を **「GitHub Actions」** にする．
3. **Actions** タブ → *Build and deploy website* → 最新の実行（または *Run workflow*）が緑になるのを待つ（初回は R パッケージ導入で 5〜10 分程度，2回目以降はキャッシュで短縮）．
4. Settings → Pages に表示されるURLを開く．

> リポジトリが非公開（private）の場合，無料プランでは GitHub Pages を使えません（公開リポジトリにするか有料プラン）．

## 2. 新サイトの動作確認

公開URLで次を確認します（スマートフォンでも）：

- [ ] 日本語トップ `/website/` と英語トップ `/website/en/` が表示される
- [ ] 右上の「English」/「日本語」で同じページの別言語版に移動できる（Achievements も）
- [ ] Achievements の PDF アイコン・DOI リンク・HUSCAP リンクが開ける
- [ ] Research / Posts は非公開（メニューになく，`/website/about.html` 等は 404）
- [ ] 存在しないURL（例 `/website/xxx`）で 404 ページが表示され，メニューのリンクが機能する
- [ ] `/website/sitemap.xml` に日英両方のページがある
- [ ] 旧URL互換の `/website/english.html` が `/website/en/` に移動する
- [ ] ページのソース（右クリック→ページのソースを表示）に `canonical`・`hreflang`・`og:` タグがある

自動チェック（`scripts/check_site.R`）は Actions のたびに実行されています．

## 3. Google Search Console に新サイトを登録

1. <https://search.google.com/search-console> → **プロパティを追加** → **URLプレフィックス** に
   `https://koichi-igarashi.github.io/website/` を入力（github.io ではドメインプロパティは使えません）．
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
4. **URL検査** で `https://koichi-igarashi.github.io/website/` と `.../website/en/` を検査し **インデックス登録をリクエスト**．

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
| 1〜4週間 | Google で `site:koichi-igarashi.github.io/website` を検索し，日英のページが出るか |
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
