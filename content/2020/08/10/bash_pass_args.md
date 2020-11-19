---
title: "bash脚本中传递带引号的参数"
date: 2020-08-10T10:46:03+08:00
draft: false
tags: ["bash"]
categories: ["language"]
---

用bash来执行其他文件时，若直接使用```$*```来传递参数，则会导致其中的双引号被去掉，应使用```"$@"```来传递参数
