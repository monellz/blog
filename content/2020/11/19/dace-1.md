---
title: "DaCe(SC19)分析-1"
date: 2020-11-19T10:09:38+08:00
draft: false
tags: ["python", "code reading", "sc19", "programming framework"]
categories: ["reseach"]
---

开一个新坑，对SC19的异构编程框架文章[dace](https://arxiv.org/abs/1902.10345)分析源码，顺便看一下现代python的写法以及与后端c++的协同方式

从dace的tutorial例子出发

```python
import dace
@dace.program
def getstarted(A):
    return A + A
```

啪就来个装饰器，很快啊（

首先在```dace/__init__.py```下，所有装饰被导出

```python
from .frontend.python.decorators import *
```

继续往里走就是```dace/frontend/python/decorators.py```

```python
from typing import Callable

#############################################

# Type hint specifically for the @dace.program decorator
paramdec_program: Callable[..., Callable[..., parser.DaceProgram]] = paramdec


@paramdec_program
def program(f, *args, **kwargs) -> parser.DaceProgram:
    """ DaCe program, entry point to a data-centric program. """

    # Parses a python @dace.program function and returns an object that can
    # be translated
    return parser.DaceProgram(f, args, kwargs)

```

第一句代码看起来有点绕，实质上就是

```python
paramdec_program = paramdec
```

然后给```paramdec_program```添加了注释，声明它首先是个函数，并且这个函数返回一个函数，而返回的函数会最终返回一个```parser.DaceProgram```

使用这样的注释可以在``__annotatinos__``里添加对应的信息(```__anotations__```是一个字典，key包括这里的```paramdec_program```，对应的value就是这个注释)，深层意义不明，可能后面需要这个注释进行type check？

继续看这个```paramdec```，它被定义在了```dace/dtypes.py```里

```python
def paramdec(dec):
    """ Parameterized decorator meta-decorator. Enables using `@decorator`,
        `@decorator()`, and `@decorator(...)` with the same function. """
    @wraps(dec)
    def layer(*args, **kwargs):

        # Allows the use of @decorator, @decorator(), and @decorator(...)
        if len(kwargs) == 0 and len(args) == 1 and callable(
                args[0]) and not isinstance(args[0], typeclass):
            return dec(*args, **kwargs)

        @wraps(dec)
        def repl(f):
            return dec(f, *args, **kwargs)

        return repl

    return layer
```

这就是一个很标准的装饰器了，注释里提到这些封装是为了支持各种参数数量

## 装饰器分析

反过来分析这一堆装饰器，首先看program这个装饰器

```python
@paramdec
def program(f, *args, **kwargs):
    pass
```

当用paramdec装饰后，就等价于

```python
program_wrapped = paramdec(program) = layer # 注意内部有个变量dec := program
```

### 没有参数的一般函数

考虑装饰器没有参数的一般函数

```python
@dace.program
def fibonacci(iv: dace.int32[1], res: dace.float32[1]):
    pass
```

这就等价于

```python
fibonacci_wrapped = layer(fibonacci) # 注意内部有个变量dec := program
```

由于此时layer的参数只有一个，因此内部if表达式为true（不考虑isinstance），则有最终展开为

```python
fibonacci_wrapped = program(fibonacci)
```

### 有参数的一般函数

下面考虑装饰器有参数的一般函数

```python
@dace.program(dace.float64[M, K], dace.float64[K, N], dace.float64[M, N])
def gemm(A, B, C):
    pass
```

等价于

```python
gemm_wrapped = layer(dace.float64[M, K], dace.float64[K, N], dace.float64[M, N])(gemm)
# 注意内部有个变量dec := program
```

此时layer有多个参数，内部if表达式为false，因此继续封装，将其展开如下

```python
gemm_wrapped = repl(gemm) # 此时repl的参数f即为原始的gemm
# 注意内部有
# dec := program
# args := dace.float64[M, K], dace.float64[K, N], dace.float64[M, N]

# 继续展开有
gemm_wrapped = program(gemm, dace.float64[M, K], dace.float64[K, N], dace.float64[M, N])
```

### 总结

这里的一堆嵌套装饰器主要是为了支持装饰器（指dace.program这个装饰器）的参数个数是任意的，直接根据需求来实现或许更好理解点...

## 类型检查

dace在对一个函数进行处理的时候，类型的指定可以通过装饰器参数指定，通过函数参数注释指定，或者不指定（不指定则需要参数是array等）

这部分的逻辑在dace/frontend/python/parser.py中

从上面对于装饰器的分析，最终原始函数```f```会被封装成```parser.DaceProgram(f, args, kwargs)```，其中args是装饰器的参数（指明函数的参数类型），如果装饰器没有参数，则这个为空

在parser.py中，DaceProgram构造时将这些进行保存

```python
class DaceProgram:
    """ A data-centric program object, obtained by decorating a function with
        `@dace.program`. """
    def __init__(self, f, args, kwargs):
        self.f = f
        self.args = args
        self.kwargs = kwargs
        self._name = f.__name__
        self.argnames = _get_argnames(f) # 直接获得函数f的所有参数名称
		....
```

在```DaceProgram.generate_pdp```函数的前几句，有对于类型的检查

```python
def generate_pdp(self, *compilation_args, strict=None):
    dace_func = self.f
    args = self.args

    # If exist, obtain type annotations (for compilation)
    # 通过__annotations__来得到参数类型，里面会检查参数个数是否对应
    argtypes = _get_type_annotations(dace_func, self.argnames, args)
```

