---
title: "DaCe(SC19)分析-2 DaceProgram初始化"
date: 2020-11-23T12:10:37+08:00
draft: false
tags: ["python", "code reading", "sc19", "programming framework"]
categories: ["reseach"]
---

上次说到，dace采用装饰器来修饰需要被优化的函数，最终会返回一个```parser.DaceProgram(f, args, kwargs)```，其中f是被修饰函数的指针，args是可选的装饰器参数，指定函数的参数类型

```DaceProgram```被定义在了```dace/frontend/python/parser.py```里，其初始化函数如下

```python
class DaceProgram:
    """ A data-centric program object, obtained by decorating a function with
        `@dace.program`. """
    def __init__(self, f, args, kwargs):
        self.f = f
        self.args = args
        self.kwargs = kwargs
        self._name = f.__name__
        self.argnames = _get_argnames(f)

        global_vars = _get_locals_and_globals(f)

        self.global_vars = {
            k: v
            for k, v in global_vars.items() if dtypes.isallowed(v, allow_recursive=True)
        }
        if self.argnames is None:
            self.argnames = []
```

初始化中首先保存了一些函数和其参数的必要信息到内部结构中，然后是调用```_get_argnams(f)```来获得函数的参数名称

这是一个定义在同一文件中的内部函数

```python
def _get_argnames(f):
    """ Returns a Python function's argument names. """
    try:
        return inspect.getfullargspec(f).args
    except AttributeError:
        return inspect.getargspec(f).args
```

用到了inspect库，这是python的一个标准库，```getfullargspec```能返回函数的各种信息(包括标注)，例如

```python
def f_anno(s: str, i: int) -> int:
    return int(s) + i
def f(s, i):
    return int(s) + i

inspect.getfullargspec(f_anno)
'''
FullArgSpec(args=['s', 'i'], varargs=None, varkw=None, defaults=None, kwonlyargs=[], kwonlydefaults=None, annotations={'return': <class 'int'>, 's': <class 'str'>, 'i': <class 'int'>})
'''

inspect.getfullargspec(f)
'''
FullArgSpec(args=['s', 'i'], varargs=None, varkw=None, defaults=None, kwonlyargs=[], kwonlydefaults=None, annotations={})
'''
```

dace这里捕捉了```AttributeError```异常，我理解这里是在处理python2跟python3的兼容，python2的inspect库中是没有getfullargspec这个函数的，因此会抛出一个AttributeError异常（本身dace库就明说了需要python3，感觉这个不太必要...）

获得函数的参数名称后，初始化中继续用```_get_locals_and_globals```收集函数的局部和全局变量

```python
def _get_locals_and_globals(f):
    """ Retrieves a list of local and global variables for the function ``f``.
        This is used to retrieve variables around and defined before  @dace.programs for adding symbols and constants.
    """
    result = {}
    # Update globals, then locals
    result.update(f.__globals__)
    # grab the free variables (i.e. locals)
    if f.__closure__ is not None:
        result.update({
            k: v
            for k, v in zip(f.__code__.co_freevars,
                            [x.cell_contents for x in f.__closure__])
        })

    return result
```

这部分把所有局部和全局变量导出来了，具体这些用法可以参考[stackoverflow](https://stackoverflow.com/questions/14413946/what-exactly-is-contained-within-a-obj-closure)

在收集之后，dace对其进行了筛选

```python
self.global_vars = {
	k: v
	for k, v in global_vars.items() if dtypes.isallowed(v, allow_recursive=True)
	}
```

这里```dtypes```是dace自己定义的，位于```dace/dtypes.py```，函数定义为

```python
def isallowed(var, allow_recursive=False):
    """ Returns True if a given object is allowed in a DaCe program.

        :param allow_recursive: whether to allow dicts or lists containing constants.
    """
    from dace.symbolic import symbol

    if allow_recursive:
        if isinstance(var, (list, tuple)):
            return all(isallowed(v, allow_recursive=False) for v in var)

    return isconstant(var) or ismodule(var) or isinstance(
        var, symbol) or isinstance(var, typeclass)
```

这被用来检查被优化函数中所使用到的type是否为dace所支持的

dace自己有一套typeclass来增强python原有的type系统（在```dace/dtypes.py -> typeclass```），从而能够使用```dace.float32[M, N]```等type

至此DaceProgram初始化完毕

### 例子

最后用一个简单的例子来看下具体DaceProgram一些内部变量

```python
N = dace.symbol('N')
@dace.program
def sum(A: dace.float32[N], out: dace.float32[1]):
    dace.reduce(lambda a, b: a + b, A, out, identity=0)
    
type(sum)
'''
<class 'dace.frontend.python.parser.DaceProgram'>
'''

sum.args
'''
()
''' # 为空是因为装饰器没指定参数

sum.global_vars
'''
sum.global_vars
{'__name__': '__main__', '__builtins__': <module 'builtins' (built-in)>, 'dace': <module 'dace' from '/home/zhongrunxin/spack/opt/spack/linux-ubuntu16.04-haswell/gcc-7.3.0/python-3.8.6-pjue5cqk6ficyr6bb35bqrccldl256ps/lib/python3.8/site-packages/dace/__init__.py'>, 'N': N}
'''
```



