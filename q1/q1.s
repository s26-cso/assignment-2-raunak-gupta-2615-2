    .text

# ============================================================
# struct Node* make_node(int val)
#   - Allocates a new Node, sets val, left=NULL, right=NULL
#   - Returns pointer to the node
# ============================================================
    .globl make_node

make_node:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx            # save callee-saved register
    subq    $8, %rsp        # align stack to 16 bytes
    
    movl    %edi, %ebx      # save val in %ebx
    movq    $24, %rdi       # malloc(24)
    call    malloc
    
    movl    %ebx, (%rax)    # node->val = val
    movq    $0, 8(%rax)     # node->left = NULL
    movq    $0, 16(%rax)    # node->right = NULL
    
    addq    $8, %rsp        # restore stack
    popq    %rbx            # restore callee-saved register
    popq    %rbp
    ret
# ============================================================
# struct Node* insert(struct Node* root, int val)
#   - Inserts a node with value val into the BST
#   - Returns the root of the tree
# ============================================================
    .globl insert
insert:
    pushq   %rbp
    movq    %rsp, %rbp
    pushq   %rbx
    pushq   %r12

    movq    %rdi, %rbx              # %rbx = root
    movl    %esi, %r12d             # %r12d = val

    # If root == NULL, create a new node and return it
    testq   %rdi, %rdi
    jnz     .insert_not_null

    movl    %r12d, %edi
    call    make_node
    jmp     .insert_done

.insert_not_null:
    # Compare val with root->val
    movl    (%rbx), %eax            # eax = root->val
    cmpl    %eax, %r12d             # compare val with root->val
    jl      .insert_go_left
    jg      .insert_go_right

    # val == root->val: duplicate, just return root
    movq    %rbx, %rax
    jmp     .insert_done

.insert_go_left:
    movq    8(%rbx), %rdi           # rdi = root->left
    movl    %r12d, %esi             # esi = val
    call    insert
    movq    %rax, 8(%rbx)           # root->left = insert(root->left, val)
    movq    %rbx, %rax              # return root
    jmp     .insert_done

.insert_go_right:
    movq    16(%rbx), %rdi          # rdi = root->right
    movl    %r12d, %esi             # esi = val
    call    insert
    movq    %rax, 16(%rbx)          # root->right = insert(root->right, val)
    movq    %rbx, %rax              # return root

.insert_done:
    popq    %r12
    popq    %rbx
    popq    %rbp
    ret

# ============================================================
# struct Node* get(struct Node* root, int val)
#   - Searches for val in the BST
#   - Returns pointer to node if found, NULL otherwise
# ============================================================
    .globl get
get:
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %rax        # current = root

.get_loop:
    testq %rax, %rax
    jz .get_not_found

    movl (%rax), %ecx
    cmpl %ecx, %esi
    je .get_found
    jl .get_go_left

    # go right
    movq 16(%rax), %rax
    jmp .get_loop

.get_go_left:
    movq 8(%rax), %rax
    jmp .get_loop

.get_not_found:
    xorq %rax, %rax

.get_found:
    popq %rbp
    ret
# ============================================================
# int getAtMost(int val, struct Node* root)
#   - Returns the greatest value in the tree <= val
#   - Returns -1 if no such node exists
# ============================================================
    .globl getAtMost
getAtMost:
    pushq   %rbp
    movq    %rsp, %rbp

    movl    $-1, %eax               # result = -1 (default)

    # rdi = val, rsi = root
    testq   %rsi, %rsi
    jz      .getAtMost_done

.getAtMost_loop:
    movl    (%rsi), %ecx            # ecx = root->val
    cmpl    %edi, %ecx              # compare root->val with val
    je      .getAtMost_exact
    jg      .getAtMost_go_left
    # root->val < val: this is a candidate, go right for better
    movl    %ecx, %eax              # result = root->val (candidate)
    movq    16(%rsi), %rsi          # root = root->right
    testq   %rsi, %rsi
    jnz     .getAtMost_loop
    jmp     .getAtMost_done

.getAtMost_go_left:
    # root->val > val: go left
    movq    8(%rsi), %rsi           # root = root->left
    testq   %rsi, %rsi
    jnz     .getAtMost_loop
    jmp     .getAtMost_done

.getAtMost_exact:
    movl    %ecx, %eax              # result = root->val (exact match)

.getAtMost_done:
    popq    %rbp
    ret
