.data
filename:
    .string "input.txt"          # Name of the file to read (hardcoded as per spec)
yes_str:
    .string "Yes\n"              # Output string when palindrome (4 bytes: Y e s \n)
no_str:
    .string "No\n"               # Output string when not palindrome (3 bytes: N o \n)

    .text
    .globl main
main:
    # Function prologue: set up stack frame and save callee-saved registers
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %r12                  # r12 will store file descriptor
    pushq   %r13                  # r13 will store file size
    pushq   %r14                  # r14 will store left index (from start)
    pushq   %r15                  # r15 will store right index (from end)
    subq    $16, %rsp             # Allocate stack space for local variables (2 bytes for chars)

    # ============================================================
    # Step 1: Open input.txt for reading
    # ============================================================
    # System call: open (syscall number 2)
    movq    $2, %rax
    leaq    filename(%rip), %rdi  # const char *filename = "input.txt"
    xorq    %rsi, %rsi            # int flags = O_RDONLY (0)
    xorq    %rdx, %rdx            # mode_t mode = 0 (not needed for read-only)
    syscall                       # Returns file descriptor in %rax, or -1 on error
    
    testq   %rax, %rax            # Check if error occurred (negative return value)
    js      .print_no             # If negative, cannot open file -> print No
    movq    %rax, %r12            # Save file descriptor in r12 (preserved across calls)

    # ============================================================
    # Step 2: Get file size using lseek to SEEK_END
    # This allows us to know the string length without reading the whole file
    # ============================================================
    # System call: lseek (syscall number 8)
    movq    $8, %rax
    movq    %r12, %rdi            # int fd = file descriptor
    xorq    %rsi, %rsi            # off_t offset = 0
    movq    $2, %rdx              # int whence = SEEK_END (2)
    syscall                       # Returns file offset (size) in %rax
    movq    %rax, %r13            # r13 = file_size (number of bytes/characters)

    # ============================================================
    # Step 3: Edge cases - empty string (size 0) or single character (size 1)
    # Both are trivially palindromes
    # ============================================================
    cmpq    $1, %r13              # Compare file_size with 1
    jle     .print_yes            # If size <= 1, it's a palindrome

    # ============================================================
    # Step 4: Initialize two pointers for two-pointer palindrome check
    # This achieves O(1) space by only storing two indices
    # ============================================================
    xorq    %r14, %r14            # r14 = left = 0 (index from start)
    leaq    -1(%r13), %r15        # r15 = right = size - 1 (index from end)

    # ============================================================
    # Step 5: Main palindrome checking loop
    # Compare characters from both ends, moving inward
    # Time complexity: O(n/2) = O(n), Space: O(1)
    # ============================================================
.check_loop:
    # Check if left and right pointers have crossed or met
    cmpq    %r15, %r14
    jge     .print_yes            # If left >= right, all characters matched -> palindrome

    # ============================================================
    # Read character at position 'left' from the file
    # ============================================================
    # First, seek to the left position using lseek
    movq    $8, %rax              # lseek syscall
    movq    %r12, %rdi            # file descriptor
    movq    %r14, %rsi            # offset = left index
    xorq    %rdx, %rdx            # whence = SEEK_SET (0)
    syscall                       # Move file pointer to left position

    # Read exactly 1 byte (one character) from the current file position
    xorq    %rax, %rax            # syscall number for read is 0
    movq    %r12, %rdi            # file descriptor
    leaq    -1(%rbp), %rsi        # buffer address (stack location, 1 byte before base pointer)
    movq    $1, %rdx              # count = 1 (read one character)
    syscall                       # Read character into stack
    
    # Verify we actually read 1 byte (end of file shouldn't happen here)
    cmpq    $1, %rax              # Check if exactly 1 byte was read
    jne     .print_no             # If not, file is corrupted or truncated -> not palindrome

    # ============================================================
    # Read character at position 'right' from the file
    # ============================================================
    # Seek to the right position
    movq    $8, %rax              # lseek syscall
    movq    %r12, %rdi            # file descriptor
    movq    %r15, %rsi            # offset = right index
    xorq    %rdx, %rdx            # whence = SEEK_SET (0)
    syscall                       # Move file pointer to right position

    # Read exactly 1 byte from the right position
    xorq    %rax, %rax            # read syscall
    movq    %r12, %rdi            # file descriptor
    leaq    -2(%rbp), %rsi        # buffer address (different stack location, 2 bytes before base)
    movq    $1, %rdx              # count = 1
    syscall                       # Read character into stack
    
    # Verify we read 1 byte
    cmpq    $1, %rax              # Check if exactly 1 byte was read
    jne     .print_no             # If not, file is corrupted -> not palindrome

    # ============================================================
    # Compare the two characters read from left and right positions
    # ============================================================
    movb    -1(%rbp), %al         # al = character from left position
    movb    -2(%rbp), %cl         # cl = character from right position
    cmpb    %cl, %al              # Compare left char with right char
    jne     .print_no             # If they differ, not a palindrome

    # ============================================================
    # Move pointers inward: left++, right--
    # ============================================================
    incq    %r14                  # left = left + 1 (move toward center)
    decq    %r15                  # right = right - 1 (move toward center)
    jmp     .check_loop           # Continue checking next pair

    # ============================================================
    # Print "Yes" when palindrome is confirmed
    # ============================================================
.print_yes:
    # Close the file descriptor (good practice, though OS will clean up on exit)
    movq    $3, %rax              # close syscall number
    movq    %r12, %rdi            # file descriptor
    syscall                       # close(input.txt)
    
    # Write "Yes\n" to stdout (file descriptor 1)
    movq    $1, %rax              # write syscall number
    movq    $1, %rdi              # stdout file descriptor
    leaq    yes_str(%rip), %rsi   # pointer to "Yes\n" string
    movq    $4, %rdx              # length = 4 bytes ('Y','e','s','\n')
    syscall                       # Output "Yes"
    jmp     .exit                 # Jump to program exit

    # ============================================================
    # Print "No" when not a palindrome or file error occurs
    # ============================================================
.print_no:
    # Close the file descriptor only if it was successfully opened
    # r12 is negative only if open() failed (checked earlier)
    cmpq    $0, %r12              # Compare file descriptor with 0 (valid FDs are >=0)
    jl      .skip_close           # If r12 < 0, file was never opened -> skip close
    
    # Close the file descriptor
    movq    $3, %rax              # close syscall
    movq    %r12, %rdi            # file descriptor
    syscall                       # Close the file
    
.skip_close:
    # Write "No\n" to stdout
    movq    $1, %rax              # write syscall
    movq    $1, %rdi              # stdout
    leaq    no_str(%rip), %rsi    # pointer to "No\n" string
    movq    $3, %rdx              # length = 3 bytes ('N','o','\n')
    syscall                       # Output "No"

    # ============================================================
    # Program exit: restore registers and return
    # ============================================================
.exit:
    addq    $16, %rsp             # Deallocate stack space for local variables
    popq    %r15                  # Restore r15 (right index)
    popq    %r14                  # Restore r14 (left index)
    popq    %r13                  # Restore r13 (file size)
    popq    %r12                  # Restore r12 (file descriptor)
    popq    %rbp                  # Restore base pointer
    xorl    %eax, %eax            # Return 0 (success)
    ret