# 基本設定

## 概要
基本的な描画を司る設定です。シェーダーの種類（不透明、半透明、屈折など）や片面・両面描画の切り替えなど、まず最初に設定するようなプロパティがまとまっています。

## パラメーター

|名前|説明|
|-|-|
|描画モード|不透明やカットアウト、半透明や屈折など描画の種類の設定です。|
|Cutoff|透明度がこの数値以下になると完全透明になります。|
|Cull Mode (描画面)|指定した面のみ描画します。両面描画より片面描画の方が負荷が小さくなります。|
|背面の法線を反転|面が裏側である場合にライティングなどの処理を反転させます。|
|裏面を影にする|面の裏側を強制的に暗くする度合いです。服の裏側等が不自然に明るいと感じたとき等に使用します。|
|非表示|オンのときはマテリアルが非表示になります。|
|ZWrite|奥行き情報を書き込むかどうかです。基本的にオンがオススメですが、透過マテリアルではオフにすると描画の問題が改善されることがあります。|
|Render Queue|マテリアルを描画する順序を決める際に使われる数値です。大きいほど後に描画されます。透過マテリアル同士が重なって片方が消えてしまう場合は手前に表示されるマテリアルのRender Queueを上げると改善されることがあります。|

## 描画モード一覧

|描画モード|説明|
|-|-|
|不透明|透過を無視します。|
|カットアウト|透過を利用しますが半透明の描画はできません。|
|半透明|透過を利用します。半透明のオブジェクト同士が重なると片方が見えなくなる場合があります。表情や髪の毛の透け等に利用します。|
|[高負荷] 屈折|透けている部分が歪んで見えるようになります。|
|[高負荷] 屈折ぼかし|屈折表現に加えすりガラスのようなぼかしも行えます。|
|[高負荷] ファー|毛のような表現ができます。柔らかい印象になりますが、前後関係の描画が不自然になる場合があります。|
|[高負荷] ファー (カットアウト)|毛のような表現ができます。カットアウトで描画するため硬い印象になりますが、アンチエイリアスが適用される環境下ではいくらか改善されます。|
|[高負荷] ファー (2パス)|毛のような表現ができます。透過とカットアウトのファーをブレンドすることでそれぞれのデメリットを緩和します。|
|[高負荷] 宝石|複雑な屈折表現を行います。|