.text

# ============================================================
# struct Node* make_node(int val)
#   - Allocates a new Node, sets val, left=NULL, right=NULL
#   - Returns pointer to the node
# ============================================================
    .globl make_node

make_node:
    # Standard function prologue: set up stack frame for debugging and backtraces
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Save callee-saved register %rbx because we will use it to hold 'val'
    # across the malloc call (malloc may clobber %rdi, %rsi, %rdx, %rcx, %r8, %r9,
    # but must preserve %rbx, %r12, %r13, %r14, %r15, %rbp)
    pushq   %rbx
    
    # Align stack to 16 bytes as required by the x86-64 ABI before a call.
    subq    $8, %rsp        # align stack to 16 bytes for malloc
    
    # Save the input parameter (val) in %ebx because %edi will be overwritten by malloc's argument
    movl    %edi, %ebx      # save val in %ebx
    
    # malloc(24): size of struct Node = 4 (int) + 8 (left pointer) + 8 (right pointer) = 24 bytes
    movq    $24, %rdi       # malloc(24)
    call    malloc          # returns pointer in %rax (or NULL on failure)
    
    # Initialize the newly allocated node
    movl    %ebx, (%rax)    # node->val = val (first 4 bytes)
    movq    $0, 8(%rax)     # node->left = NULL (bytes 8-15)
    movq    $0, 16(%rax)    # node->right = NULL (bytes 16-23)
    
    # Function epilogue: clean up stack and restore registers
    addq    $8, %rsp        # restore stack (undo the alignment subtraction)
    popq    %rbx            # restore callee-saved register %rbx
    popq    %rbp            # restore base pointer
    ret                     # return pointer to new node in %rax

# ============================================================
# struct Node* insert(struct Node* root, int val)
#   - Inserts a node with value val into the BST
#   - Returns the root of the tree
# ============================================================
    .globl insert
insert:
    # Function prologue
    pushq   %rbp
    movq    %rsp, %rbp
    
    # Save callee-saved registers we will use
    pushq   %rbx            # will hold root
    pushq   %r12            # will hold val

    # Save parameters in callee-saved registers so they survive recursive calls
    movq    %rdi, %rbx              # %rbx = root
    movl    %esi, %r12d             # %r12d = val

    # Base case: If root == NULL, create a new node and return it
    testq   %rdi, %rdi              # test if root is NULL
    jnz     .insert_not_null        # if not NULL, go to recursive case

    # root is NULL: create a new node with the given value
    movl    %r12d, %edi             # set argument for make_node (val)
    call    make_node               # create new node, returns pointer in %rax
    jmp     .insert_done            # return the new node (becomes new root or leaf)

.insert_not_null:
    # Compare val with root->val to decide left or right
    movl    (%rbx), %eax            # eax = root->val
    cmpl    %eax, %r12d             # compare val with root->val
    
    jl      .insert_go_left         # if val < root->val, go left
    jg      .insert_go_right        # if val > root->val, go right

    # val == root->val: duplicate value, do nothing, just return root (no duplicates)
    movq    %rbx, %rax              # return original root
    jmp     .insert_done

.insert_go_left:
    # Recursively insert into left subtree
    movq    8(%rbx), %rdi           # rdi = root->left (first argument for insert)
    movl    %r12d, %esi             # esi = val (second argument)
    call    insert                  # insert(root->left, val) returns new left subtree root
    movq    %rax, 8(%rbx)           # root->left = returned pointer
    movq    %rbx, %rax              # return original root (unchanged as current root)
    jmp     .insert_done

.insert_go_right:
    # Recursively insert into right subtree
    movq    16(%rbx), %rdi          # rdi = root->right
    movl    %r12d, %esi             # esi = val
    call    insert                  # insert(root->right, val)
    movq    %rax, 16(%rbx)          # root->right = returned pointer
    movq    %rbx, %rax              # return original root

.insert_done:
    # Function epilogue: restore saved registers and return
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
    # Minimal stack frame: only need to save %rbp for debugging, no other registers
    # because this function is iterative and uses only %rax and %rcx (scratch)
    pushq %rbp
    movq %rsp, %rbp
    movq %rdi, %rax        # current = root (start at root)

.get_loop:
    # Check if current node is NULL
    testq %rax, %rax
    jz .get_not_found      # if NULL, value not found

    # Compare current node's value with search key
    movl (%rax), %ecx      # ecx = current->val
    cmpl %ecx, %esi        # compare val (in %esi) with current->val
    je .get_found          # if equal, found it
    jl .get_go_left        # if val < current->val, go left

    # val > current->val: go right
    movq 16(%rax), %rax    # current = current->right
    jmp .get_loop          # continue search

.get_go_left:
    # val < current->val: go left
    movq 8(%rax), %rax     # current = current->left
    jmp .get_loop          # continue search

.get_not_found:
    xorq %rax, %rax        # return NULL (0)

.get_found:
    # %rax already holds pointer to found node (or NULL)
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

    # Initialize result to -1 (no valid value found yet)
    # -1 is chosen because the problem guarantees valid integers (non-negative? but safe default)
    movl    $-1, %eax               # result = -1 (default)

    # Check if tree is empty
    # rdi = val, rsi = root
    testq   %rsi, %rsi
    jz      .getAtMost_done         # if root == NULL, return -1

.getAtMost_loop:
    # Get current node's value
    movl    (%rsi), %ecx            # ecx = root->val
    cmpl    %edi, %ecx              # compare root->val with val
    je      .getAtMost_exact        # exact match is automatically the greatest <= val
    jg      .getAtMost_go_left      # if root->val > val, all right subtree values are larger, so go left
    
    # root->val < val: this value is a valid candidate (it is <= val)
    # But there might be a larger value (closer to val) in the right subtree
    movl    %ecx, %eax              # update result = root->val (candidate)
    movq    16(%rsi), %rsi          # root = root->right (try to find a larger value that is still <= val)
    testq   %rsi, %rsi
    jnz     .getAtMost_loop         # if right child exists, continue searching
    jmp     .getAtMost_done         # no right child, current result is the best possible

.getAtMost_go_left:
    # root->val > val: current node too large, go left to find smaller values
    movq    8(%rsi), %rsi           # root = root->left
    testq   %rsi, %rsi
    jnz     .getAtMost_loop         # if left child exists, continue
    jmp     .getAtMost_done         # no left child, return current result (might still be -1)

.getAtMost_exact:
    # Exact match found: this is the greatest value <= val (since it equals val)
    movl    %ecx, %eax              # result = root->val (exact match)

.getAtMost_done:
    popq    %rbp
    ret