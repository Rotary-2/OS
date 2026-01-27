#include "print.h"

void main(void) {
    put_str("I am kernel of put_str\n");
    while(1); // 死循环防止程序退出
}