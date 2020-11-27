---
title: "获取当前时间的性能坑"
date: 2020-11-27T15:01:42+08:00
draft: false
tag: ["linux", "performance", "fine tune"]
categories: ["performance"]
---

一般获取当前时间戳是使用

```c++
// 对于c++
auto start = std::chrono::high_resolution_clock::now();
// auto end = std::chrono::high_resolution_clock::now();
// double tot = std::chrono::duration_cast<std::chrono::duration<double>>(end - start).count();

// 对于linux/c
#include <sys/time.h>
timeval tv;
gettimeofday(&start, NULL);
```

在x86架构下，这俩函数都是用了vdso(virtual dynamic shared object)/vsyscall来避免syscall的使用从而加速，但这里有个坑是如果编译时采用```-static```的话，最后得到的二进制文件实际是包含syscall的，这极大降低了它的性能

我理解是```-static```所链接的静态库里没有实现对于时间获取的用户态加速，以后遇到这个问题保险做法还是得```objdump```检查下具体实现....

下面是一些性能数据

*   动态链接

    | ns/op | evaluating get_time                     |
    | ----- | --------------------------------------- |
    | 43.97 | gettimeofday                            |
    | 47.80 | std::chrono::high_resolution_clock::now |

*   静态链接(使用```-static```)

    | ns/op  | evaluating get_time                     |
    | ------ | --------------------------------------- |
    | 527.65 | gettimeofday                            |
    | 526.82 | std::chrono::high_resolution_clock::now |

可以看到有超过10倍的性能差距....