---
title: "hugo博客中添加google analytics"
date: 2020-11-23T15:23:45+08:00
draft: false
categories: ["blog"]
tags: ["web", "blog"]
---

想在这个博客中添加一下流量统计就整了下google analytics

hugo在官网里说了已经内部支持google analytics，只需要在config文件里指定ID并在head里添加就行[here](https://gohugo.io/templates/internal/)

但看起来似乎是hugo没有跟上google analytics的发展，我在捣鼓analytics的时候一直找不到UA-XXXX-X这样的tracking id，只有G-XXXXX这样的ID，我尝试了把官网教程中的UA-XXXX替换成G-XXXX，但并没有什么用

查看一下hugo内部的analytics模版，发现它跟google analytics给的代码模版不一致，那我就只能手动hard code了

把themes/minos/layouts/partials/footer.html中的调用hugo内部analytics模版删掉

```html
    {{ template "_internal/google_analytics_async.html" . }} # 删掉
```

然后写入google analytics推荐的code

```html

    <!-- Global site tag (gtag.js) - Google Analytics -->
    <script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXX"></script>
    <script>
        window.dataLayer = window.dataLayer || [];
        function gtag(){dataLayer.push(arguments);}
        gtag('js', new Date());

        gtag('config', 'G-XXXXX');
    </script>

```

现在就能在google analytics的实时监控平台看到访问信息了～