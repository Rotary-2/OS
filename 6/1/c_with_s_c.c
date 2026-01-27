extern void asm_print(char*, int);      // 声明汇编函数

void c_print(char* str) {
    int len = 0;
    while (str[len++]);         // 计算字符串长度
    asm_print(str, len);        // 调用汇编函数
}