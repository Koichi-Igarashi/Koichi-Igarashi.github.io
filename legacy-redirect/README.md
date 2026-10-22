# 旧 Quarto Pub サイトの転送ページ

旧サイト <https://igapipy.quarto.pub/koichi-igarashi/> の各ページを，新サイト
<https://koichi-igarashi.github.io/website/> の **同じページ** へ転送するための小さな Quarto プロジェクトです．

## なぜこの方式か

- Quarto Pub ではサーバー側の HTTP 301 リダイレクトを設定できません（設定項目・`_redirects` 等の仕組みがない静的ホスティング）．
- Google は **0秒の meta refresh を恒久的なリダイレクト（301 相当）として扱います**
  （[Redirects and Google Search](https://developers.google.com/search/docs/crawling-indexing/301-redirects)）．
  各ページには さらに新URLへの `rel="canonical"` と JavaScript の転送も入れています．
- Search Console の「アドレス変更ツール」は 301 が必須で，ドメイン単位のプロパティのみ対象のため，
  `igapipy.quarto.pub/koichi-igarashi/` からの移転には使えません
  （[Change of Address tool](https://support.google.com/webmasters/answer/9370220)）．
- 旧ページに `noindex` は付けません（転送が評価を引き継ぐため不要．付けると転送より先に検索結果から消える恐れ）．

| 旧URL | 新URL |
|---|---|
| `/koichi-igarashi/` | `/website/` |
| `/koichi-igarashi/about.html` | `/website/`（Research は新サイトでは非公開のためホームへ） |
| `/koichi-igarashi/achievements.html` | `/website/achievements.html` |
| `/koichi-igarashi/posts.html` | `/website/`（Posts は非公開のためホームへ） |
| `/koichi-igarashi/english.html` | `/website/en/` |
| `/koichi-igarashi/posts/test/` | `/website/`（同上） |

非公開ページをホームへ転送した旧URLは，Google では「ソフト404」扱いになり，やがて検索結果から外れます（非公開にするという意図どおり）．
Research / Posts を新サイトで再公開する場合は，`about.qmd` などの `redirect-path` を元のページ（`about.html` 等）に戻してから公開してください．

## ⚠️ 期限：2026年12月31日まで

Posit の告知では，Quarto Pub への **公開（更新）は 2026-12-31 に終了** し，既存コンテンツは 2031-12-31 まで現在のURLで表示され続けます
（[Posit blog: Migrating to Connect Cloud](https://posit.co/blog/migrating-connect-cloud-posits-unified-publishing-solution)．
この作業環境からは記事本文を直接開けず検索結果の要約で確認したため，日付は公式告知でも確認してください）．
**転送ページの公開は必ず 2026年中に行ってください．** それ以降は旧サイトを一切変更できなくなります．

## 手順

**前提：新サイトが公開済みで，全ページが表示できること**（[../docs/migration-guide.md](../docs/migration-guide.md) の手順 1〜3）．
新サイトが表示できない状態で転送を公開すると，旧サイトの訪問者も検索エンジンも行き場を失います．

1. 新サイトのURLを確認し，`_quarto.yml` の `new-site-url` が一致していることを確認（既定: `https://koichi-igarashi.github.io/website`）．
   URLを独自ドメイン等に変える予定があるなら，**変更後のURLで** 転送を公開してください（2回目の変更はできません）．
2. 手元のPC（Quarto Pub にログインできる環境）で：

   ```sh
   cd legacy-redirect
   quarto render                  # _site/ に転送ページを生成
   # _site/index.html をブラウザで開き，新サイトへ移動することを確認
   quarto publish quarto-pub      # _publish.yml の既存サイトID（9a28de94-…）へ上書き公開
   ```

   - 初回はブラウザで Quarto Pub の認証を求められます．公開先が `https://igapipy.quarto.pub/koichi-igarashi` と表示されることを確認してから進めてください．
   - **リポジトリのルートでは `quarto publish quarto-pub` を実行しないでください．**（旧来の `_publish.yml` はこのフォルダに移動済み）
3. 公開後の確認：

   ```sh
   bash legacy-redirect/check_redirects.sh
   ```

   すべて ✓ になれば完了です．ブラウザでも旧URLを開き，新サイトの対応ページが表示されることを確認してください．
4. Search Console で転送の認識を確認（[../docs/migration-guide.md](../docs/migration-guide.md) の手順 5）．

## 元に戻したいとき（2026-12-31 まで）

転送前の旧サイトに戻すには，転送を公開する前のコミット（このフォルダを追加する前，例 `git checkout 0a9384f`）で
リポジトリルートから `quarto publish quarto-pub` を実行します（当時の R パッケージ環境が必要）．

## 旧サイトの削除について

- 削除は必須ではありません（2031年末まで転送ページが残り，評価を引き継ぎ続けます）．
- 削除する場合も，Google の推奨に従い **転送公開から最低1年以上**，かつ Search Console で旧URLへの検索流入がほぼ無くなってから行ってください．
- 削除は quartopub.com の管理画面（サイト → Danger Zone → Delete）から本人が行います．
