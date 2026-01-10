; 主引导程序
SECTION MBR vstart = 0x7c00
    ; 初始化段寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ds, ax
    mov fs, ax
    mov sp, 0x7c00  ; 栈指针初始化
    
    ; 清屏功能(INT 0x10, AH = 0x06)
    ; AL = 0:全部行; BH = 属性(0x07灰底白字)
    ; CX = (0, 0):左上角坐标; DX = (24, 79):右下角坐标
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0x0000
    mov dx, 0x184f
    int 0x10

    ; 获取光标位置(INT 0x10, AH = 0x03)
    ; BH = 0:第0页
    mov ah, 0x0300
    mov bx, 0x0000
    int 0x10

    ; 打印字符串(INT 0x10, AH = 0x13)
    ; ES:BP = 字符串地址; CX = 字符串长度
    ; DH = 行号 ; DL = 列号 ; BL = 属性(0x02绿字)
    mov ax, message
    mov bp, ax
    mov cx, 5
    mov bx, 0x0002
    int 0x10

    imp $ ; 无限循环

message db "1 MBR"
times 510 - ($ - $$) db 0   ; 计算剩余空间填充
db 0x55, 0xaa  ; MBR结束标志
