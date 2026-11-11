/* Identical RV32I workload for both CPUs, independent of UART and counter.
 * 32x32-bit stack RAM, 256 iterations of ALU/load/store/branch/shift.
 * No multiply/divide/CSR. Caller-saved regs, sp restored. MIT.
 */
.section .text.w01work, "ax", @progbits
.balign 4
.globl w01_workload
.type w01_workload, @function
w01_workload:
  addi sp, sp, -128
  li t0, 0x12345678
  li t1, 0
  li t2, 32
.Linitialize:
  slli t3, t0, 5
  srli t4, t0, 3
  xor t0, t3, t4
  xor t0, t0, t1
  slli t3, t1, 2
  add t4, sp, t3
  sw t0, 0(t4)
  addi t1, t1, 1
  blt t1, t2, .Linitialize
  li t5, 0x9e3779b9
  li t1, 0
  li t2, 256
.Lupdate:
  andi t3, t1, 31
  slli t3, t3, 2
  add t3, sp, t3
  lw t4, 0(t3)
  slli t6, t0, 7
  xor t0, t0, t6
  srli t6, t0, 9
  xor t0, t0, t6
  slli t6, t0, 8
  xor t0, t0, t6
  add t6, t4, t0
  add t6, t6, t1
  srli t4, t4, 3
  xor t6, t6, t4
  sw t6, 0(t3)
  slli t4, t5, 3
  srli a0, t5, 29
  or t5, t4, a0
  xor t5, t5, t6
  andi t4, t6, 1
  beq t4, zero, .Leven
  li t4, 0xa5a5a5a5
  add t5, t5, t4
  j .Lnext
.Leven:
  li t4, 0x3c6ef372
  xor t5, t5, t4
.Lnext:
  addi t1, t1, 1
  blt t1, t2, .Lupdate
  li t1, 0
  li t2, 32
.Lreduce:
  slli t3, t1, 2
  add t3, sp, t3
  lw t4, 0(t3)
  add t5, t5, t4
  slli t6, t5, 5
  srli a0, t5, 27
  or t5, t6, a0
  addi t1, t1, 1
  blt t1, t2, .Lreduce
  mv a0, t5
  addi sp, sp, 128
  ret
.size w01_workload, .-w01_workload
