%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
jmp loader_start

; 构建gdt及其内部的描述符
GDT_BASE: dd    0x00000000
          dd    0x00000000

CODE_DESC:dd    0x0000FFFF
          dd    DESC_CODE_HIGH4

DATA_STACK_DESC: dd     0x0000FFFF
                 dd     DESC_DATA_HIGH4
                 
VIDEO_DESC: dd  0x80000007  ; limit = (0xbffff - 0xb8000) / 4k = 0x7 显存段0x000B8000
            dd DESC_VIDEO_HIGH4 ; 此时dp1为0

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1

times 60 dq 0           ; 此处预留60个描述符的空位

SELECTOR_CODE   equ     (0x0001 << 3) + TI_GDT + RPL0
SELECTOR_DATA   equ     (0x0002 << 3) + TI_GDT + RPL0
SELECTOR_VIDEO  equ     (0x0003 << 3) + TI_GDT + RPL0

; 以下是gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
gdt_ptr dw  GDT_LIMIT
        dd  GDT_BASE
        
loadermsg db '2 loader in real.'

loader_start:

; -------------------------------
; INT 0x10  功能号:0x13     功能描述：打印字符串
mov ax, cs
mov es, ax
mov sp, LOADER_BASE_ADDR
mov bp, loadermsg   ; ES:BP = 字符串地址
mov cx, 17          ; CX = 字符串长度
mov ax, 0x1301      ; AH = 13子功能号
                    ; AL = 1:字符串中只含显示字符，其显示属性在BL中; 显示后，光标位置改变
mov bx, 0x001f      ; 页号为0(BH = 0)蓝底粉红字(BL = 1fh)
mov dx, 0x1800      ; 坐标
int 0x10            ; 10h中断

; --------------------------------
; 准备进入保护模式：
; 1.打开A20
; 2.加载gdt
; 3.将cr0的pe位置1
; ------------ 打开A20 ------------
in al, 0x92
or al, 0000_0010B
out 0x92, al
;------------- 加载gdt ------------
lgdt [gdt_ptr]
; ----------cr0第0位置1 -----------
mov eax, cr0
or eax, 0x00000001
mov cr0, eax

jmp dword SELECTOR_CODE:p_mode_start   ; 刷新流水线

[bits 32]
p_mode_start:
mov ax, SELECTOR_DATA
mov ds, ax
mov es, ax
mov ss, ax

mov esp, LOADER_STACK_TOP

; 初始化内存分页管理
call setup_page                 ; 创建页目录、页表并初始化位图

; 调整全局描述符表(GDT)地址映射
sgdt [gdt_ptr]                  ; 保存当前GDT地址信息

; 更新显存段描述符基址(第三个描述符)
; 将物理地址0x000B8000改为虚拟地址0xC00B8000
mov ebx, [gdt_ptr + 2]          ; +2跳过gdt_ptr前2字节界限，获取GDT的基地址
or dword [ebx + 0x18 + 4], 0xc0000000   ; 将基地址映射到内核空间

; 将GDT基址和栈指针映射到高地址空间
add dword [gdt_ptr + 2], 0xc0000000     ; GDT基址映射
add esp, 0xc0000000             ; 栈指针重映射

; 启用分页机制
mov eax, PAGE_DIR_TABLE_POS
mov cr3, eax

mov eax, cr0
or eax, 0x80000000
mov cr0, eax                    ; 设置CR0的PG位

; 重新加载更新后的GDT
lgdt [gdt_ptr]

; 重新加载视频段选择子
mov ax, SELECTOR_VIDEO
mov gs, ax

; 现在可以安全访问内存
mov byte [gs:160], 'V'
; 系统挂起
jmp $

; ----------------- 页目录及页表初始化 -----------------
setup_page:
    ; 清零页目录区域 一次清空4字节 清空1024次 共4096字节
    xor esi, esi
    mov ecx, 1024
.clear_dir:
    mov dword [PAGE_DIR_TABLE_POS + esi*4], 0
    inc esi
    loop .clear_dir

    ; 确定第一个页表
    mov eax, PAGE_DIR_TABLE_POS + 0x1000    ; 第一个页表属性
    or eax, PG_US_U | PG_RW_W | PG_P        ; 设置页目录项属性

    ; 映射目录项0和768到同一页表
    mov [PAGE_DIR_TABLE_POS + 0x0], eax     ; 目录项0   -> 第一个页表
    mov [PAGE_DIR_TABLE_POS + 0xc00], eax   ; 目录项768 -> 第一个页表

    ; 设置自映射目录项
    mov eax, PAGE_DIR_TABLE_POS
    or eax, PG_US_U | PG_RW_W | PG_P
    mov [PAGE_DIR_TABLE_POS + 4092], eax    ; 目录项1023 -> 页目录自身

    ; 初始化第一个页表的256个PTE(一起映射低端1MB内存 物理地址0开始)
    mov edi, PAGE_DIR_TABLE_POS + 0x1000   ; 第一个页表地址
    mov eax, PG_US_U | PG_RW_W |  PG_P     ; 物理地址0 + 属性
    mov ecx, 256                           ; 256个页表项
.init_pte:
    mov [edi], eax
    add edi, 4
    add eax, 4096                         ; 下一物理页
    loop .init_pte

    ; 初始化页目录项769-1022号，内核空间PDE
    mov edi, PAGE_DIR_TABLE_POS + 0x2000    ; 第二个页表开始
    mov ebx, PAGE_DIR_TABLE_POS + 769 * 4   ; 目录项769地址
    mov ecx, 254                            ; 254个目录项
.init_kernel_pde:
    mov eax, edi
    or eax, PG_US_U | PG_RW_W | PG_P
    mov [ebx], eax                        ; 设置页目录项
    add ebx, 4                            ; 下一个目录项
    add edi, 0x1000                       ; 下一个页表
    loop .init_kernel_pde
    ret