#include "init.h"
#include "print.h"
#include "interrupt.h"
#include "timer.h"
#include "memory.h"
#include "thread.h"
#include "console.h"
#include "keyboard.h"

/* 负责初始化所有模块 */
void init_all() {
    put_str("init_all\n");
    idt_init();         // 中断初始化中断
    timer_init();       // 定时器初始化    
    thread_init();      // 初始化线程相关结构
    mem_init();	        // 初始化内存管理系统
    console_init();     // 终端初始化
    keyboard_init();    // 键盘初始化
}