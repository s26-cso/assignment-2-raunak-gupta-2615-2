    .data
space_str:
    .string " "
newline_str:
    .string "\n"
fmt_int:
    .string "%d"

    .text
    .globl main

# ============================================================
# main(int argc, char** argv)
#
# 1. Parse command-line args (argv[1..argc-1]) into int array
# 2. Run next_greater algorithm with a stack (O(n) time/space)
# 3. Print space-separated result
# ============================================================
main:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    # argc in %edi, argv in %rsi
    movl    %edi, %r12d             # r12d = argc
    movq    %rsi, %r13              # r13 = argv

    # n = argc - 1 (number of elements)
    movl    %r12d, %r14d
    subl    $1, %r14d               # r14d = n

    # If n <= 0, just exit
    testl   %r14d, %r14d
    jle     .main_exit

    # Allocate arr[n] on stack (each int = 4 bytes)
    movslq  %r14d, %r15             # r15 = n (64-bit)
    leaq    0(,%r15,4), %rax        # rax = n * 4
    subq    %rax, %rsp
    # Align stack to 16 bytes
    andq    $-16, %rsp
    movq    %rsp, %rbx              # rbx = arr base pointer

    # Parse argv[1..n] into arr
    xorl    %ecx, %ecx              # ecx = i = 0
.parse_loop:
    cmpl    %r14d, %ecx
    jge     .parse_done

    subq    $8, %rsp                # maintain 16-byte alignment
    pushq   %rcx                    # save i
    # argv[i+1]
    movl    %ecx, %eax
    addl    $1, %eax
    movslq  %eax, %rax
    movq    (%r13,%rax,8), %rdi     # rdi = argv[i+1]
    call    atoi
    popq    %rcx                    # restore i
    addq    $8, %rsp                # restore alignment

    movl    %eax, (%rbx,%rcx,4)     # arr[i] = atoi(argv[i+1])
    incl    %ecx
    jmp     .parse_loop

.parse_done:
    # Allocate result[n] on stack (each int = 4 bytes)
    leaq    0(,%r15,4), %rax
    subq    %rax, %rsp
    andq    $-16, %rsp
    movq    %rsp, %r12              # r12 = result base pointer

    # Initialize result[i] = -1 for all i
    xorl    %ecx, %ecx
.init_result:
    cmpl    %r14d, %ecx
    jge     .init_done
    movl    $-1, (%r12,%rcx,4)
    incl    %ecx
    jmp     .init_result

.init_done:
    # Allocate stack[n] on the actual stack (indices, each int = 4 bytes)
    leaq    0(,%r15,4), %rax
    subq    %rax, %rsp
    andq    $-16, %rsp
    movq    %rsp, %r13              # r13 = stack base pointer

    # stack_top = -1 (empty stack; stack_top stored in r15d, reuse r15)
    # But r15 was n. Save n in a different place.
    # Let's use: r14d = n, r15d = stack_top
    movl    $-1, %r15d              # r15d = stack_top = -1

    # for (i = n-1; i >= 0; i--)
    movl    %r14d, %ecx
    subl    $1, %ecx                # ecx = i = n-1

.algo_loop:
    cmpl    $0, %ecx
    jl      .algo_done

    # while (stack_top >= 0 && arr[stack.top()] <= arr[i]) stack.pop()
.while_loop:
    cmpl    $0, %r15d
    jl      .while_done             # stack empty

    # stack.top() = stack[stack_top]
    movslq  %r15d, %rax
    movl    (%r13,%rax,4), %edx     # edx = stack[stack_top] (index j)

    # arr[j] vs arr[i]
    movl    (%rbx,%rdx,4), %eax     # eax = arr[j]
    movl    (%rbx,%rcx,4), %esi     # esi = arr[i]
    cmpl    %esi, %eax
    jg      .while_done             # arr[j] > arr[i], stop

    # pop: stack_top--
    decl    %r15d
    jmp     .while_loop

.while_done:
    # if (!stack.empty()) result[i] = stack.top()
    cmpl    $0, %r15d
    jl      .skip_assign

    movslq  %r15d, %rax
    movl    (%r13,%rax,4), %eax     # eax = stack[stack_top]
    movl    %eax, (%r12,%rcx,4)     # result[i] = stack.top()

.skip_assign:
    # stack.push(i): stack_top++; stack[stack_top] = i
    incl    %r15d
    movslq  %r15d, %rax
    movl    %ecx, (%r13,%rax,4)     # stack[stack_top] = i

    decl    %ecx                    # i--
    jmp     .algo_loop

.algo_done:
    # Print result: space-separated
    xorl    %ecx, %ecx              # ecx = i = 0
.print_loop:
    cmpl    %r14d, %ecx
    jge     .print_done

    subq    $8, %rsp                # maintain 16-byte alignment
    pushq   %rcx                    # save i

    # Print space before element (if not first)
    testl   %ecx, %ecx              # changed: use register directly
    jz      .skip_space

    leaq    space_str(%rip), %rdi
    xorl    %eax, %eax
    call    printf

.skip_space:
    movq    (%rsp), %rcx            # restore i (peek)
    # Print result[i]
    leaq    fmt_int(%rip), %rdi
    movl    (%r12,%rcx,4), %esi
    xorl    %eax, %eax
    call    printf

    popq    %rcx                    # restore i
    addq    $8, %rsp                # restore alignment

    incl    %ecx
    jmp     .print_loop

.print_done:
    # Print newline
    leaq    newline_str(%rip), %rdi
    xorl    %eax, %eax
    call    printf

.main_exit:
    # Restore stack frame
    # We did multiple subq from rsp, but we saved rbp
    leaq    -40(%rbp), %rsp
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    popq    %rbp

    xorl    %eax, %eax
    ret