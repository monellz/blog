---
title: "DaCe(SC19)分析-3 编译和生成"
date: 2020-11-24T12:10:37+08:00
draft: false
tags: ["python", "code reading", "sc19", "programming framework"]
categories: ["reseach"]
---

继续之前的DaceProgram

DaceProgram重写了自己的```__call__```，因此被dace装饰的函数，将会在被调用时进行编译和运行

```python
def __call__(self, *args, **kwargs):
    """ Convenience function that parses, compiles, and runs a DaCe 
        program. """
    # Parse SDFG
    sdfg = parse_from_function(self, *args)

    # Add named arguments to the call
    kwargs.update({aname: arg for aname, arg in zip(self.argnames, args)})

    # Update arguments with symbols in data shapes
    kwargs.update(infer_symbols_from_shapes(sdfg, kwargs))

    # Allow CLI to prompt for optimizations
    if Config.get_bool('optimizer', 'transform_on_call'):
        sdfg = sdfg.optimize()

    # Compile SDFG (note: this is done after symbol inference due to shape
    # altering transformations such as Vectorization)
    binaryobj = sdfg.compile()
    return binaryobj(**kwargs)
```

## 获得Statefull DataFlow multiGraph（SDFG）

首先将从函数来parse得到sdfg，使用同一文件定义的```parse_from_function```

```python
def parse_from_function(function, *compilation_args, strict=None):
    """ Try to parse a DaceProgram object and return the `dace.SDFG` object
        that corresponds to it.
        :param function: DaceProgram object (obtained from the `@dace.program`
                         decorator).
        :param compilation_args: Various compilation arguments e.g. dtypes.
        :param strict: Whether to apply strict transformations or not (None
                       uses configuration-defined value). 
        :return: The generated SDFG object.
    """
    # Avoid import loop
    from dace.sdfg.analysis import scalar_to_symbol as scal2sym
    from dace.transformation import helpers as xfh

    if not isinstance(function, DaceProgram):
        raise TypeError(
            'Function must be of type dace.frontend.python.DaceProgram')

    # Obtain DaCe program as SDFG
    sdfg = function.generate_pdp(*compilation_args, strict=strict)

    # Apply strict transformations automatically
    if (strict == True or
        (strict is None
         and Config.get_bool('optimizer', 'automatic_strict_transformations'))):

        # Promote scalars to symbols as necessary
        promoted = scal2sym.promote_scalars_to_symbols(sdfg)
        if Config.get_bool('debugprint') and len(promoted) > 0:
            print('Promoted scalars {%s} to symbols.' %
                  ', '.join(p for p in sorted(promoted)))

        sdfg.apply_strict_transformations()

        # Split back edges with assignments and conditions to allow richer
        # control flow detection in code generation
        xfh.split_interstate_edges(sdfg)

    # Save the SDFG (again)
    sdfg.save(os.path.join('_dacegraphs', 'program.sdfg'))

    # Validate SDFG
    sdfg.validate()

    return sdfg
```

可以看到，主要的工作函数是```function.generate_pdp```（function也就是对应的DaceProgram本身）来获得sdfg，然后进行了一些变换

### Parse a DaCe program

在```generate_pdp```函数中（我理解这里pdp是指parsed dace program)，首先获得参数的type注释

```python
argtypes = _get_type_annotations(dace_func, self.argnames, args)
# dace_func指待优化的函数的指针
# argnames就是之前通过inspect库获得的函数参数名称（注意不是type名称）
# args就是调用函数是给的参数
```

这里就用到了之前dace装饰器的参数和函数的参数注释（如果有的话），有几点规定

1.  DaCe Program不应该有返回值的注释，因为是通过参数返回的
2.  DaCe Program要么有函数参数注释，要么有装饰器参数，不能同时存在
3.  装饰器参数 or 函数注释参数的个数应当与实际函数的参数个数一致（实际函数的参数来自于上述的```self.argnames```

检查完这些后就返回一个字典，其中key是参数名称，value是对应的参数类型描述，这个描述并不是直接的```int/str```等，而是dace自己的一套描述，来自于```dace/data.py```的```create_datadescripto```函数

```python
def create_datadescriptor(obj):
    """ Creates a data descriptor from various types of objects.
        @see: dace.data.Data
    """
    from dace import dtypes  # Avoiding import loops
    if isinstance(obj, Data):
        return obj

    try:
        return obj.descriptor
    except AttributeError:
        if isinstance(obj, numpy.ndarray):
            return Array(dtype=dtypes.typeclass(obj.dtype.type),
                         shape=obj.shape)
        if symbolic.issymbolic(obj):
            return Scalar(symbolic.symtype(obj))
        if isinstance(obj, dtypes.typeclass):
            return Scalar(obj)
        if obj in {int, float, complex, bool}:
            return Scalar(dtypes.typeclass(obj))
        return Scalar(dtypes.typeclass(type(obj)))
```

这里进行比较的Data是```dace.data.Data```

```python
@make_properties
class Data(object):
    """ Data type descriptors that can be used as references to memory.
        Examples: Arrays, Streams, custom arrays (e.g., sparse matrices).
    """
```

Dace是对python中各种基础类型进行了增强，除此之外也定义了各种新的type

这个增强的type里包含了本身基础type，shape，storage，lifetime等等有用的property

到此，回到DaceProgram的generate_pdp函数，argtypes收集完毕（如果这一步没有收集，则通过调用时给的参数来进行收集）

然后就是处理modules和全局变量的一些东西

generate_pdp返回时来最终进行AST的parse

```python
# Parse AST to create the SDFG
return newast.parse_dace_program(dace_func, argtypes, global_vars, modules, other_sdfgs, self.kwargs, strict=strict)
```

```newast```在```dace/frontend/newast.py```

在实际parse时，dace使用了ast, inspect等等库来从原函数指针中获得对应的ast以及源码，然后使用自定义的```ProgramVisitor```（来自```dace/frontend/python/newast.py```）来遍历ast并生成对应的sdfg

至此，初始的sdfg生成完毕，在进行compile之前，会对sdfg进行一些```strict```的transformation，所谓strict的变换就是被认为总能提高性能的变换，所有的变换方法被分别定义在了```dace/transformation```文件夹下，里面会标注是否是strict的

## 编译SDFG

编译sdfg调用```sdfg.compile()```（被定义在```dace/sdfg/sdfg.py```）

编译sdfg实际上是根据sdfg进行代码生成，然后编译生成可运行的binary

初始会判断是否使用已生成的binary，有就直接返回了

然后就是主要编译部分了，包括代码生成等

```python
    # Generate code for the program by traversing the SDFG state by state
    program_objects = codegen.generate_code(sdfg)

    # Generate the program folder and write the source files
    program_folder = compiler.generate_program_folder(
        sdfg, program_objects, sdfg.build_folder)

    # Compile the code and get the shared library path
    shared_library = compiler.configure_and_compile(program_folder,
                                                    sdfg.name)

    # If provided, save output to path or filename
    if output_file is not None:
        if os.path.isdir(output_file):
            output_file = os.path.join(output_file,
                                        os.path.basename(shared_library))
        shutil.copyfile(shared_library, output_file)

    # Get the function handle
    return compiler.get_program_handle(shared_library, sdfg)
```

### 代码生成

```codegen.generate_code(sdfg)```函数会获得一个code object列表，每个code object都是一个file，里面也包含了target，编译参数，环境等等

### 文件夹生成

上述说的code object都还是python对象，这一步将会把里面的代码写入文件中（当前目录下），通过调用```compiler.generate_program_folder```

### 编译并获得函数句柄

编译是通过cmake进行编译，将代码编译成共享库

在```dace/codegen/compiled_sdfg.py```中定义了```ReloadableDLL```来处理共享库的load（使用诸如subprocess命令行执行，ctypes的CDLL和shutil等方式）

然后利用同一文件下定义的```CompiledSDFG```以及重写的```__call___```来封装对于共享库函数的调用

到此为止，完整的函数调用结束



## 
