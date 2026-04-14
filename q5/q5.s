.data
filename:
    .string "input.txt"
yes_str:
    .string "Yes\n"
no_str:
    .string "No\n"
    .text
    .globl main
main:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15
    subq    $16, %rsp

    # Open input.txt
    movq    $2, %rax
    leaq    filename(%rip), %rdi
    xorq    %rsi, %rsi
    xorq    %rdx, %rdx
    syscall
    testq   %rax, %rax
    js      .print_no
    movq    %rax, %r12              # r12 = fd

    # Get file size: lseek(fd, 0, SEEK_END)
    movq    $8, %rax
    movq    %r12, %rdi
    xorq    %rsi, %rsi
    movq    $2, %rdx
    syscall
    movq    %rax, %r13              # r13 = file_size

    # Edge cases: size 0 or 1 is always a palindrome
    cmpq    $1, %r13
    jle     .print_yes

    xorq    %r14, %r14              # r14 = left = 0
    leaq    -1(%r13), %r15          # r15 = right = size-1

.check_loop:
    cmpq    %r15, %r14
    jge     .print_yes

    # lseek to left
    movq    $8, %rax
    movq    %r12, %rdi
    movq    %r14, %rsi
    xorq    %rdx, %rdx
    syscall

    # read left char
    xorq    %rax, %rax
    movq    %r12, %rdi
    leaq    -1(%rbp), %rsi
    movq    $1, %rdx
    syscall
    cmpq    $1, %rax                # ← check exactly 1 byte read
    jne     .print_no

    # lseek to right
    movq    $8, %rax
    movq    %r12, %rdi
    movq    %r15, %rsi
    xorq    %rdx, %rdx
    syscall

    # read right char
    xorq    %rax, %rax
    movq    %r12, %rdi
    leaq    -2(%rbp), %rsi
    movq    $1, %rdx
    syscall
    cmpq    $1, %rax                # ← check exactly 1 byte read
    jne     .print_no

    # Compare characters
    movb    -1(%rbp), %al
    movb    -2(%rbp), %cl
    cmpb    %cl, %al
    jne     .print_no

    incq    %r14
    decq    %r15
    jmp     .check_loop

.print_yes:
    movq    $3, %rax
    movq    %r12, %rdi
    syscall
    movq    $1, %rax
    movq    $1, %rdi
    leaq    yes_str(%rip), %rsi
    movq    $4, %rdx
    syscall
    jmp     .exit

.print_no:
    cmpq    $0, %r12
    jl      .skip_close
    movq    $3, %rax
    movq    %r12, %rdi
    syscall
.skip_close:
    movq    $1, %rax
    movq    $1, %rdi
    leaq    no_str(%rip), %rsi
    movq    $3, %rdx
    syscall

.exit:
    addq    $16, %rsp
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbp
    xorl    %eax, %eax
    ret