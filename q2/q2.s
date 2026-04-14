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
    # Function prologue: set up stack frame and save callee-saved registers
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx
    pushq   %r12
    pushq   %r13
    pushq   %r14
    pushq   %r15

    # argc in %edi, argv in %rsi (x86-64 System V ABI)
    movl    %edi, %r12d             # r12d = argc (save for later)
    movq    %rsi, %r13              # r13 = argv (save for later)

    # n = argc - 1 (number of elements to process, excluding program name)
    movl    %r12d, %r14d
    subl    $1, %r14d               # r14d = n

    # If n <= 0, no elements to process, just exit
    testl   %r14d, %r14d
    jle     .main_exit

    # Allocate arr[n] on stack (each int = 4 bytes)
    # Convert n to 64-bit for address calculations
    movslq  %r14d, %r15             # r15 = n (64-bit)
    leaq    0(,%r15,4), %rax        # rax = n * 4 (bytes needed)
    subq    %rax, %rsp              # allocate array on stack (grows downward)
    # Align stack to 16 bytes after allocation (required for future calls like atoi, printf)
    andq    $-16, %rsp
    movq    %rsp, %rbx              # rbx = base pointer of arr array

    # Parse argv[1] through argv[n] into arr[0] through arr[n-1]
    xorl    %ecx, %ecx              # ecx = i = 0 (loop counter)
.parse_loop:
    cmpl    %r14d, %ecx             # compare i with n
    jge     .parse_done             # if i >= n, done parsing

    # Save alignment before calling atoi (which follows C calling convention)
    subq    $8, %rsp                # maintain 16-byte alignment (compensate for push)
    pushq   %rcx                    # save i on stack (caller-saved across atoi)

    # argv[i+1] because argv[0] is program name
    movl    %ecx, %eax
    addl    $1, %eax                # i+1
    movslq  %eax, %rax              # 64-bit index
    movq    (%r13,%rax,8), %rdi     # rdi = argv[i+1] (first argument to atoi)
    call    atoi                    # atoi returns integer in %eax

    popq    %rcx                    # restore i
    addq    $8, %rsp                # restore alignment

    movl    %eax, (%rbx,%rcx,4)     # arr[i] = atoi(argv[i+1])
    incl    %ecx                    # i++
    jmp     .parse_loop

.parse_done:
    # Allocate result[n] on stack (same size as arr)
    leaq    0(,%r15,4), %rax        # rax = n * 4
    subq    %rax, %rsp              # allocate result array
    andq    $-16, %rsp              # maintain 16-byte alignment
    movq    %rsp, %r12              # r12 = base pointer of result array

    # Initialize result[i] = -1 for all i (default when no greater element exists)
    xorl    %ecx, %ecx              # i = 0
.init_result:
    cmpl    %r14d, %ecx             # compare i with n
    jge     .init_done              # if i >= n, done
    movl    $-1, (%r12,%rcx,4)      # result[i] = -1
    incl    %ecx                    # i++
    jmp     .init_result

.init_done:
    # Allocate stack[n] on the stack (stores indices, each int = 4 bytes)
    # This stack will hold indices of elements waiting to find their next greater element
    leaq    0(,%r15,4), %rax        # rax = n * 4
    subq    %rax, %rsp              # allocate stack array
    andq    $-16, %rsp              # maintain 16-byte alignment
    movq    %rsp, %r13              # r13 = base pointer of stack array

    # stack_top = -1 (empty stack; r15d will be reused for stack top)
    # Note: r15 previously held n (64-bit), but now we reuse r15d for stack top
    movl    $-1, %r15d              # r15d = stack_top = -1 (empty stack)

    # Main algorithm: iterate from right to left (n-1 down to 0)
    # This is efficient because we can maintain a monotonic decreasing stack
    movl    %r14d, %ecx             # ecx = n
    subl    $1, %ecx                # ecx = i = n-1 (start from last element)

.algo_loop:
    cmpl    $0, %ecx                # compare i with 0
    jl      .algo_done              # if i < 0, done

    # While stack is not empty AND arr[stack.top()] <= arr[i], pop from stack
    # This maintains a strictly decreasing stack (from bottom to top)
    # Reason: we want the next greater element, so smaller or equal elements are useless
.while_loop:
    cmpl    $0, %r15d               # compare stack_top with 0
    jl      .while_done             # if stack_top < 0 (stack empty), exit loop

    # Get the index at the top of the stack
    movslq  %r15d, %rax             # rax = stack_top (64-bit index)
    movl    (%r13,%rax,4), %edx     # edx = stack[stack_top] (index j)

    # Compare arr[j] with arr[i]
    movl    (%rbx,%rdx,4), %eax     # eax = arr[j] (value at index j)
    movl    (%rbx,%rcx,4), %esi     # esi = arr[i] (value at index i)
    cmpl    %esi, %eax
    jg      .while_done             # if arr[j] > arr[i], stop popping (found candidate)

    # arr[j] <= arr[i]: this element cannot be the next greater for i or any earlier element
    # Pop it by decrementing stack_top (logical removal)
    decl    %r15d                   # stack_top--
    jmp     .while_loop             # continue checking new top

.while_done:
    # If stack is not empty, the top of stack contains the index of the next greater element
    cmpl    $0, %r15d               # check if stack is empty
    jl      .skip_assign            # if empty, result[i] remains -1

    # stack not empty: result[i] = stack.top() (the index of next greater element)
    movslq  %r15d, %rax             # rax = stack_top (64-bit)
    movl    (%r13,%rax,4), %eax     # eax = stack[stack_top] (index)
    movl    %eax, (%r12,%rcx,4)     # result[i] = stack.top()

.skip_assign:
    # Push current index i onto the stack (as a candidate for previous elements)
    # First increment stack_top, then store i at that position
    incl    %r15d                   # stack_top++
    movslq  %r15d, %rax             # rax = stack_top (64-bit)
    movl    %ecx, (%r13,%rax,4)     # stack[stack_top] = i

    decl    %ecx                    # i-- (move left to next element)
    jmp     .algo_loop

.algo_done:
    # Print result array as space-separated integers
    xorl    %ecx, %ecx              # ecx = i = 0
.print_loop:
    cmpl    %r14d, %ecx             # compare i with n
    jge     .print_done             # if i >= n, done printing

    # Save alignment before calling printf
    subq    $8, %rsp                # maintain 16-byte alignment for printf
    pushq   %rcx                    # save i on stack (printf may clobber)

    # Print space before element (if not the first element, i != 0)
    testl   %ecx, %ecx              # check if i == 0
    jz      .skip_space             # if i == 0, skip printing space

    # Print a single space character
    leaq    space_str(%rip), %rdi   # first argument: format string " "
    xorl    %eax, %eax              # no vector registers used (clear for varargs)
    call    printf

.skip_space:
    # Restore i from stack (peek without popping)
    movq    (%rsp), %rcx            # restore i (saved value from pushq %rcx)
    
    # Print result[i]
    leaq    fmt_int(%rip), %rdi     # first argument: format string "%d"
    movl    (%r12,%rcx,4), %esi     # second argument: result[i]
    xorl    %eax, %eax              # clear eax (no vector registers for varargs)
    call    printf

    popq    %rcx                    # restore i (remove from stack)
    addq    $8, %rsp                # restore alignment

    incl    %ecx                    # i++
    jmp     .print_loop

.print_done:
    # Print newline character to end the output line
    leaq    newline_str(%rip), %rdi # format string "\n"
    xorl    %eax, %eax              # no vector registers
    call    printf

.main_exit:
    # Restore stack frame: undo all stack allocations
    # We allocated arr, result, and stack on the stack, plus saved registers
    # The stack pointer was modified multiple times; we restore by moving back to saved %rbp
    leaq    -40(%rbp), %rsp         # -40 because we pushed 5 registers (8*5 = 40 bytes)
    popq    %r15
    popq    %r14
    popq    %r13
    popq    %r12
    popq    %rbx
    popq    %rbp

    xorl    %eax, %eax              # return 0 (success)
    ret