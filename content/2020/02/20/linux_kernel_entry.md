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

## 多CPU启动

```c
boot_cpu_init();
setup_nr_cpu_ids();
setup_per_cpu_areas();
boot_cpu_state_init();
smp_prepare_boot_cpu();
```

### boot_cpu_init

在```start_kernel```中调用```boot_cpu_init()```位于```kernel/cpu.c```，用于```activate the first processor```

```smp_processor_id()```被定义在```include/linux/smp.h```

```c
#ifdef CONFIG_DEBUG_PREEMPT
  extern unsigned int debug_smp_processor_id(void);
# define smp_processor_id() debug_smp_processor_id()
#else
# define smp_processor_id() raw_smp_processor_id()
#endif
```

在hikey970中没有设置```CONFIG_DEBUG_PREEMPT```因此为```raw_smp_processor_id()```

```c
//arch/arm64/include/asm/smp.h
#define raw_smp_processor_id() (current_thread_info()->cpu)

static inline struct thread_info *current_thread_info(void)
{
	unsigned long sp_el0;
	asm ("mrs %0, sp_el0" : "=r" (sp_el0));
    
	return (struct thread_info *)sp_el0;
}
//arch/arm64/include/asm/thread_info.h
struct thread_info {
	unsigned long		flags;		/* low level flags */
	mm_segment_t		addr_limit;	/* address limit */
	struct task_struct	*task;		/* main task structure */
#ifdef CONFIG_ARM64_SW_TTBR0_PAN
	u64			ttbr0;		/* saved TTBR0_EL1 */
#endif
	int			preempt_count;	/* 0 => preemptable, <0 => bug */
	int			cpu;		/* cpu */
};
```

### setup_nr_cpu_ids

```c
/* An arch may set nr_cpu_ids earlier if needed, so this would be redundant */
void __init setup_nr_cpu_ids(void)
{
	nr_cpu_ids = find_last_bit(cpumask_bits(cpu_possible_mask),NR_CPUS) + 1;
}
```

### setup_per_cpu_areas

```c
//arch/arm64/mm/numa.c
```

arch/arm64/kernel/smp.c

__cpu_up