#include "init.h"
#include "print.h"
#include "interrupt.h"
#include "timer.h"
#include "memory.h"

/* 负责初始化所有模块 */
void init_all() {
    put_str("init_all\n");
    idt_init();         // 中断初始化中断
    timer_init();       // 定时器初始化    
    mem_init();	  // 初始化内存管理系统
}