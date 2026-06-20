# 鉄脚先生 予想メモ

個人利用向けのAndroid APKです。

## 役割

- GitHub Actionsで生成した `generated/tekkyaku/latest.json` を読む
- 今日の一押し、前日的中、現在の的中率を表示する
- note投稿用の本文をクリップボードへコピーする

## APK

GitHub Actionsの `Build Tekkyaku Android APK` から `tekkyaku-draft-debug-apk` artifactをダウンロードします。

## データ更新

予想データは `Generate Tekkyaku Predictions` workflowで生成します。
毎日21:15 JSTと翌朝7:30 JSTに自動実行します。手動実行もできます。
