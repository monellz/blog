---
title: "hikey970开发板环境配置与PMU读取"
date: 2020-02-18T21:53:34+08:00
draft: false
tags: ["board", "colab_ex"]
categories: ["hardware"]
---


## 开发板参数
hikey970开发板参数如下




其对应的kernel源码在[这里](https://github.com/96boards-hikey/linux/tree/hikey970-v4.9)

## PMU读取
烧写的系统为lebian9

由于架构为armv8，github上有个很好的用作参考的库,[enable_arm_pmu](https://github.com/rdolbeau/enable_arm_pmu)

* 解决编译问题

    enable_arm_pmu需要先往内核插入一个模块，因此需要相应架构头文件等进行模块的编译

    板子上的```uname -r```会有奇怪的版本号出现，无法通过包管理器等进行头文件等的安装以及库里Makefile的使用

    因此直接利用源码(下面被放在了```linux-headers-hikey970-v4.9.zip```里)，在对应位置手动进行目录的构建
    ```bash
    #!/bin/bash
    #run by root

    mkdir -p /lib/modules/`uname -r`
    mv /home/shunya/linux-headers-hikey970-v4.9.zip /usr/src/
    cd /usr/src
    unzip linux-headers-hikey970-v4.9.zip
    rm linux-headers-hikey970-v4.9.zip

    cd linux-headers-hikey970-v4.9
    apt-get install bc
    gunzip < /proc/config.gz > .config
    make oldconfig
    make prepare
    make scripts

    cd /lib/modules/`uname -r`
    ln -s /usr/src/linux-headers-hikey970-v4.9 build
    ```
* kernel源码dts中添加pmu(支持perf_event)
    
    在arch/arm64/boot/dts/hisilicon/kirin970-hikey970.dts中添加如下
    ```c
    pmu {
       compatible = "arm,armv8-pmuv3";
       interrupts = <0 24 4>,
                    <0 25 4>,
                    <0 26 4>,
                    <0 27 4>,
                    <0 2 4>,
                    <0 3 4>,
                    <0 4 4>,
                    <0 5 4>;
       interrupt-affinity = <&cpu0>,
                            <&cpu1>,
                            <&cpu2>,
                            <&cpu3>,
                            <&cpu4>,
                            <&cpu5>,
                            <&cpu6>,
                            <&cpu7>;
    };
    ```

## 测试
实际测试中发现在单核(其他cpu被disable)情况下pmu(寄存器)读取十分稳定，但在多核情况仍然会出现illegal instruction的问题
