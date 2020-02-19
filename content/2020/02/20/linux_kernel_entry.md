---
title: "Linux kernel入口"
date: 2020-02-20T00:54:03+08:00
draft: false
tags: ["linux kernel", "colab_ex"]
categories: ["os"]
---


入口为```init/main.c```中的```start_kernel```函数

经过一系列的初始化，最后调用```rest_init()```，在这个函数里，最终调用```cpu_startup_entry```(位于```kernel/sched/idle.c```)，通过```cpu_idle_loop()```进入idle线程的循环


从kern.log来看，一开始只有cpu0是启动的，在第一次进入idle之后，开始一个个enable其他的cpu

而module的加载还在后面
