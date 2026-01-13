%include "boot.inc"

section loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR
ARDS_SIZE       equ 20          ; 20字节
MB_SIZE         equ 0x100000    ; 1M
SWAP_SIGNATURE  equ 0x534D4150  ; "SWAP"签名 用于验证BIOS中断返回数据的有效性

; 内存检测变量
total_mem_bytes     dd 0
ards_count          dw 0
ards_buffer         times 256 db 0

jmp loader_start

; 构建gdt及其内部的描述符
GDT_BASE: dq    0x0000000000000000  ; 空描述符
          dq    0x00CF9A000000FFFF  ; 代码段
          dq    0x00CF92000000FFFF  ; 数据段

GDT_SIZE equ $ - GDT_BASE
GDT_LIMIT equ GDT_SIZE - 1

times 60 dq 0           ; 此处预留60个描述符的空位

SELECTOR_CODE   equ     (0x0001 << 3) + TI_GDT + RPL0
SELECTOR_DATA   equ     (0x0002 << 3) + TI_GDT + RPL0
SELECTOR_VIDEO  equ     (0x0003 << 3) + TI_GDT + RPL0

; 以下是gdt的指针，前2字节是gdt界限，后4字节是gdt起始地址
gdt_ptr dw  GDT_LIMIT
        dd  GDT_BASE

loader_start:
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, LOADER_STACK_TOP

; ============================================================
; 内存检测主函数
; 输出：成功时EDX = 内存容量，失败时EDX = 0
; ============================================================
detect_memory:
    mov ax, cs
    mov ds, ax
    mov ss, ax
    mov sp, LOADER_STACK_TOP

    ; 方法1：E820 - 详细内存映射
    call detect_memory_e820
    test edx, edx               ; 检查EDX(返回值)是否为0
    jnz memory_detected_success

    ; 方法2：E801 - 最大4GB
    call detect_memory_e801
    test edx, edx
    jnz memory_detected_success

    ; 方法3: 88 - 最大64MB
    call detect_memory_88
    test edx, edx
    jnz memory_detected_success

    ; 所有方法失败
    jmp error_halt

memory_detected_success:
    mov [total_mem_bytes], edx
    ret

; ===========================================================
; E820内存检测
; ===========================================================
detect_memory_e820:
    push es             ; 保存ES寄存器
    push ds
    pop es              ; 设置ES = DS

    xor ebx, ebx        ; EBX = 0(初始后续值)
    mov edi, ards_buffer
    mov word [ards_count], 0

.e820_loop:
    mov eax, 0xE820     ; 功能号：E820
    mov ecx, 20         ; ECX = 20(ARDS大小)
    mov edx, SWAP_SIGNATURE ; EDX = "SWAP"(签名)
    int 0x15
    jc .e820_failed

    ; 验证签名
    cmp eax, SWAP_SIGNATURE     ; 添加签名验证
    jne .e820_failed

    add edi, ecx
    inc word [ards_count]

    test ebx, ebx
    jnz .e820_loop

    ; 分析ARDS
    call analyze_ards
    pop es                      ; 恢复ES
    ret

.e820_failed:
    xor edx, edx
    pop es                      ; 恢复ES
    ret

; ===========================================================
; 分析ARDS结构
; ===========================================================
analyze_ards:
    movzx ecx, word [ards_count]    ; ECX = ARDS数量
    test ecx, ecx                   ; 添加安全检查
    jz .analysis_failed

    mov esi, ards_buffer
    xor edx, edx

.analyze_loop:
    ; 只处理可用内存区域(TYPE = 1)
    cmp dword [esi + 16], 1
    jne .skip_ards

    mov eax, [esi]                  ; 基地址低32位
    add eax, [esi + 8]              ; 基地址 + 长度

    ; 检查是否溢出
    jc .skip_ards                   ; 添加溢出检查

    cmp edx, eax
    jae .skip_ards
    mov edx, eax

.skip_ards:
    add esi, ARDS_SIZE
    loop .analyze_loop

    test edx, edx                   ; 确保找到有效内存
    jnz .analysis_ok

.analysis_failed:
    xor edx, edx

.analysis_ok:
    ret

; ===========================================================
; E801内存检测
; ===========================================================
detect_memory_e801:
    mov ax, 0xE801    ; 功能号：E801
    int 0x15
    jc .e801_failed         ; CF = 1则失败

    test ax, ax             ; 添加有效性检查
    jnz .e801_failed

    ; 计算低15MB内存 AX * 1024 + 1MB
    xor edx, edx
    movzx eax, bx
    shl eax, 10                 ; * 1024
    add edx, eax                ; EDX += 低15MB字节数
    add edx, MB_SIZE            ; EDX += 1MB(补偿BIOS报告的偏移)

    ; 计算16MB以上内存BX * 64KB
    test bx, bx                 ; 检查是否有扩展内存
    jz .e801_done

    movzx eax, bx
    shl eax, 16                 ; *65536 64K
    add edx, eax

.e801_done:
    ret

.e801_failed:
    xor edx, edx
    ret

; ===========================================================
; 88内存检测
; ===========================================================
detect_memory_88:
    mov ah, 0x88    ; 功能号：88
    int 0x15
    jc .88_failed       

    test ax, ax             ; 添加有效性检查
    jnz .88_failed
    cmp ax, 0xFFFF          ; 排除错误值
    je .88_failed

    and eax, 0xFFFF         ; 确保EAX高16位为0
    shl eax, 10             ; *1024
    add eax, MB_SIZE        ; EAX += 1MB
    mov edx, eax
    ret

.88_failed:
    xor edx, edx
    ret

; ===========================================================
; 错误处理
; ===========================================================
error_halt:
    hlt         ;停机指令(等待中断)
    jmp error_halt