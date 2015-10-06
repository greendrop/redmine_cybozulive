# Cybozu Live plugin for Redmine

RedmineをサイボウズLiveに連携します。

* チケットの追加・更新内容をサイボウズLive チャットへ投稿

## Installation

```
cd #{RAILS_ROOT}/plugins
git clone https://github.com/greendrop/redmine_cybozulive.git redmine_cybozulive
```

## Configuration

### プラグイン設定

[サイボウズLive Developer Center](https://developer.cybozulive.com/) でアプリケーションを登録します。

* アプリケーションの種類  
  クライアント
* アクセスレベル  
  レベル Z

Redmine 管理 > プラグイン > Redmine Cybozulive plugin にて登録したアプリケーション情報を登録します。

* Consumer Key
* Consumer Secret

### カスタムフィールド作成

Redmine 管理 > カスタムフィールド にてカスタムフィールドを作成します。

* オブジェクト  
  プロジェクト
* 書式  
  テキスト
* 名前
  * Cybozulive Mail Address
  * Cybozulive Password
  * Cybozulive Chat Room Id
  * Cybozulive Chat Id

### プロジェクト設定

Redmine 対象プロジェクト > 設定 > 情報 にてサイボウズLive情報を登録します。

* Cybozulive Mail Address  
  サイボウズLiveのログインメールアドレス
* Cybozulive Password  
  サイボウズLiveのログインパスワード
* Cybozulive Chat Room Id  
  サイボウズLiveのチャットURL chatRoomIdパラメータ値  
  https://cybozulive.com/mpChat/view?chatRoomId=XXXXXX  
  → XXXXXX
* Cybozulive Chat Id  
  未設定（プラグインにて登録されます）
