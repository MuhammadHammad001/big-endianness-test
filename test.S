.section .data
test_value:  .word 0x11223344  # Known 32-bit value

.section .text
.option norvc
.globl _start
//defines to be used for the test.
#define MSTATUS_UBE         0x0000000000000040
#define MSTATUSH_MBE        0x00000020
#define MSTATUSH_SBE        0x00000010
#define SSTATUS_UBE         0x040
#define Umode               0x0000
#define Smode               0x0800

//Test values
#define TEST_DATA   0x12345678
#define TEST_DATA1  0xFF345678
#define REV_DATA    0x78563412


//Function to go to M to requested Mode.
.macro GOTO_LOWER_MODE LOWER_MODE
    li t2, 0x80             # MPP field mask
    csrrc t3, mstatus, t2   # Clear MPP bits
    li t2, \LOWER_MODE      # Set MPP to required mode.
    csrrs zero, mstatus, t2 # Update mstatus

    // Set mepc to the instruction after mret
    auipc t0, 0            # Get current PC
    addi t0, t0, 0x10      # Compute address of instruction after mret
    csrw mepc, t0          # Set mepc

    // Return from M-mode to S-mode
    mret                    # Switch to requested mode.
.endm

//Function to go to M to requested Mode.
.macro GO_S_TO_U_MODE
    li t2, 0x100            # SPP field mask - U mode
    csrrc t3, sstatus, t2   # Clear SPP bits

    // Set mepc to the instruction after mret
    auipc t0, 0            # Get current PC
    addi t0, t0, 0x10      # Compute address of instruction after mret
    csrw sepc, t0          # Set mepc

    // Return from M-mode to S-mode
    sret                    # Switch to requested mode.
.endm

.macro RVTEST_GOTO_MMODE
    ecall
.endm

_start:
    //Setup of trap handler.
    la t0, trap_handler
    csrw mtvec, t0

TEST_MMODE_MBE:
    jal enable_mstatush_mbe                                                 //Enable mstatush.MBE
    jal basic_instructions_enabled
    jal disable_mstatush_mbe                                                //Disable mstatush.MBE
    jal basic_instructions_disabled
    RVTEST_GOTO_MMODE

TEST_SMODE_SBE:
    jal enable_mstatush_sbe
    GOTO_LOWER_MODE Smode
    jal basic_instructions_enabled
    RVTEST_GOTO_MMODE
    jal disable_mstatush_sbe                                                //Disable mstatush.MBE
    GOTO_LOWER_MODE Smode
    jal basic_instructions_disabled
    RVTEST_GOTO_MMODE

TEST_UMODE_UBE:
    jal enable_mstatus_ube
    GOTO_LOWER_MODE Umode
    jal basic_instructions_enabled
    RVTEST_GOTO_MMODE
    jal disable_mstatus_ube                                                //Disable mstatush.MBE
    GOTO_LOWER_MODE Umode
    jal basic_instructions_disabled
    RVTEST_GOTO_MMODE

// The following verifies the test case in which the sstatus[UBE] is set, then user mode big endianness is enabled.
TEST_SMODE_UBE:
    GOTO_LOWER_MODE Smode                                                  //GO to S mode.
    jal enable_sstatus_ube
    GO_S_TO_U_MODE                                                         //GO to U mode.
    jal basic_instructions_enabled
    RVTEST_GOTO_MMODE
    csrr t0, mstatus
    GOTO_LOWER_MODE Smode                                                  //GO to S mode.
    jal disable_sstatus_ube
    GO_S_TO_U_MODE                                                         //GO to U mode.
    jal basic_instructions_disabled
    RVTEST_GOTO_MMODE


//This verifies the mprv test case.
TEST_SMODE_SBE_MPRV_CASE:
    jal enable_mstatush_sbe
    // Enable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, (1 << 17)        # MPRV bit (bit 17)
    li t2, (1 << 11)        # Set MPP=01 (S-mode) to simulate S-mode memory accesses
    or t0, t0, t1           # Enable MPRV
    or t0, t0, t2           # Set MPP=01 (S-mode)
    csrw mstatus, t0        # Write back to mstatus
    jal basic_instructions_enabled
    # Disable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, ~(1 << 17)       # Mask to clear MPRV bit
    and t0, t0, t1          # Clear MPRV
    csrw mstatus, t0        # Write back mstatus
    jal disable_mstatush_sbe                                                //Disable mstatush.MBE
    # Enable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, (1 << 17)        # MPRV bit (bit 17)
    li t2, (1 << 11)        # Set MPP=01 (S-mode) to simulate S-mode memory accesses
    or t0, t0, t1           # Enable MPRV
    or t0, t0, t2           # Set MPP=01 (S-mode)
    csrw mstatus, t0        # Write back to mstatus
    jal basic_instructions_disabled
    # Disable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, ~(1 << 17)       # Mask to clear MPRV bit
    and t0, t0, t1          # Clear MPRV
    csrw mstatus, t0        # Write back mstatus

//This verifies the mprv test case.
TEST_UMODE_UBE_MPRV_CASE:
    jal enable_mstatus_ube
    # Enable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, (1 << 17)        # MPRV bit (bit 17)
    or t0, t0, t1           # Enable MPRV
    csrw mstatus, t0        # Write back to mstatus
    jal basic_instructions_enabled
    # Disable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, ~(1 << 17)       # Mask to clear MPRV bit
    and t0, t0, t1          # Clear MPRV
    csrw mstatus, t0        # Write back mstatus
    jal disable_mstatus_ube                                                //Disable mstatush.MBE
    # Enable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, (1 << 17)        # MPRV bit (bit 17)
    or t0, t0, t1           # Enable MPRV
    csrw mstatus, t0        # Write back to mstatus
    jal basic_instructions_disabled
    # Disable MPRV (restore normal M-mode accesses)
    csrr t0, mstatus        # Read mstatus
    li t1, ~(1 << 17)       # Mask to clear MPRV bit
    and t0, t0, t1          # Clear MPRV
    csrw mstatus, t0        # Write back mstatus

    j TEST_PASS


//Helper Functions
enable_mstatush_mbe:
    // Enable mstatush MBE bit to verify loads and stores in M-Mode.
    li t0, MSTATUSH_MBE
    csrs mstatush, t0
    csrr t1, mstatush                                                            //read back to make sure it has written the correct value.
    ret

enable_mstatush_sbe:
    li t0, MSTATUSH_SBE
    csrs mstatush, t0
    csrr t1, mstatush                                                            //read back to make sure it has written the correct value.
    ret

enable_mstatus_ube:
    li t0, MSTATUS_UBE
    csrs mstatus, t0
    csrr t1, mstatus                                                             //read back to make sure it has written the correct value.
    ret

enable_sstatus_ube:
    csrr t1, sstatus                                                             //read back to make sure it has written the correct value.
    li t0, SSTATUS_UBE
    csrs sstatus, t0
    csrr t1, sstatus                                                             //read back to make sure it has written the correct value.
    ret

disable_mstatush_mbe:
    // Disable mstatush MBE bit to verify loads and stores in M-Mode.
    li t0, MSTATUSH_MBE
    csrc mstatush, t0
    csrr t1, mstatush                                                            //read back to make sure it has written the correct value.
    ret

disable_mstatush_sbe:
    li t0, MSTATUSH_SBE
    csrc mstatush, t0
    csrr t1, mstatush                                                            //read back to make sure it has written the correct value.
    ret

disable_mstatus_ube:
    li t0, MSTATUS_UBE
    csrc mstatus, t0
    csrr t1, mstatus                                                             //read back to make sure it has written the correct value.
    ret

disable_sstatus_ube:
    li t0, SSTATUS_UBE
    csrc sstatus, t0
    csrr t1, sstatus                                                             //read back to make sure it has written the correct value.
    ret

basic_instructions_enabled:
    li t0, TEST_DATA
    la t1, rvtest_data

    //Stores
    sb t0, 0(t1)
    sh t0, 4(t1)
    sw t0, 8(t1)

    //Loads with mstatus.MBE enabled
    lb t0, 8(t1)                                                            //Load a byte from where a complete word is stored

    lh t0, 8(t1)

    lw t0, 8(t1)

    lbu t0, 8(t1)                                                            //Load a byte from where a complete word is stored

    lhu t0, 8(t1)


    //Verification of signed loads

    li t0, TEST_DATA1
    la t2, rvtest_data1

    //Stores
    sb t0, 0(t2)
    sh t0, 4(t2)
    sw t0, 8(t2)

    //Loads with mstatus.MBE enabled
    lb t0, 8(t2)                                                            //Load a byte from where a complete word is stored

    lh t0, 8(t2)

    lw t0, 8(t2)

    lbu t0, 8(t2)                                                            //Load a byte from where a complete word is stored

    lhu t0, 8(t2)


    ret

basic_instructions_disabled:
    la t1, rvtest_data
    la t2, rvtest_data1

    //Loads with mstatus.MBE disabled
    lb t0, 8(t1)

    lh t0, 8(t1)

    lw t0, 8(t1)

    lbu t0, 8(t1)                                                            //Load a byte from where a complete word is stored

    lhu t0, 8(t1)


    //Verification of signed loads.

    //Loads with mstatus.MBE disabled
    lb t0, 8(t2)

    lh t0, 8(t2)

    lw t0, 8(t2)

    lbu t0, 8(t2)                                                            //Load a byte from where a complete word is stored

    lhu t0, 8(t2)

    li t0, TEST_DATA1
    //Stores
    sb t0, 0(t1)
    sh t0, 4(t1)
    sw t0, 8(t1)

    ret

//We don't expect any traps in this test, so let's keep it minimal.
trap_handler:
    # Set mstatus.MPP = 11 (M-mode) to return to M-mode
    csrr t0, mstatus        # Read mstatus
    li t1, ~(3 << 11)       # Mask to clear MPP bits
    and t0, t0, t1          # Clear MPP field
    li t1, (3 << 11)        # Set MPP = 11 (M-mode)
    or t0, t0, t1           # Apply new MPP value
    csrw mstatus, t0        # Write back mstatus

    # Set mepc to the instruction after ecall (to resume execution in M-mode)
    csrr t0, mepc           # Read the saved PC (where ecall was issued)
    addi t0, t0, 4          # Move to next instruction (skip ecall)
    csrw mepc, t0           # Set updated mepc

    mret                    # Return to M-mode

rvtest_data:
.word 0x00000000
.word 0x00000000
.word 0x00000000
rvtest_data1:
.word 0x00000000
.word 0x00000000
.word 0x00000000

//PASS-FAIL LOGIC
TEST_FAIL:
    li a0, 0        # Exit code 0
    j exit

TEST_PASS:
    li a0, 1        # Exit code 1
    j exit

# Exit Routine
exit:
write_tohost:
    la t5, tohost                 # Load address of tohost
    sw a0, 0(t5)                  # Write a0 (success/failure) to tohost
    j write_tohost                # Loop indefinitely

    .section .data
    .align 4
    .globl tohost
tohost: .word 0                   # Reserved for test status communication

    .align 4
    .globl _data_start
_data_start: .word 0              # Start of data section for test
