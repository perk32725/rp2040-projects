// --- Constants ---
.equ SIO_BASE,         0xd0000000
.equ PADS_BASE,        0x4001c000
.equ IO_BANK0_BASE,    0x40014000
.equ RESETS_BASE,      0x4000c000

// Pins for Pico W SPI to CYW43439
.equ GP23_REG_ON, (1 << 23)
.equ GP24_DATA,   (1 << 24)
.equ GP25_CS,     (1 << 25)
.equ GP29_CLK,    (1 << 29)

// 3-Wire SPI Commands (Big-Endian format for the wireless chip)
.equ CMD_SYNC,      0x00000400  // Estabishes 32-bit SPI mode
.equ CMD_LED_EN,    0x900c8804  // Enable WL_GPIO0 as Output
.equ CMD_LED_WRITE, 0x900c8004  // Set WL_GPIO0 state

.thumb_func
.global _start
.global main

_start:
main:
    // 1. Reset IO and PADS
    ldr r0, =0x4000f000        // Atomic Clear
    ldr r1, =((1 << 8) | (1 << 21)) 
    str r1, [r0]
wait_reset:
    ldr r0, =RESETS_BASE
    ldr r2, [r0, #8]
    tst r2, r1
    beq wait_reset

    bl  setup_adc_clock
    bl  check_vsys_power
    ldr r1, =1300              // Threshold for ~3.2V
    cmp r0, r1
    blt stop_here              // If VSYS is too low, don't try wireless

    // Restore GP29 to SIO function (Function 5)
    ldr r1, =IO_BANK0_BASE
    add r1, #0x80
    mov r0, #5
    str r0, [r1, #0x6c]        // GPIO29_CTRL

    // Restore PADS for GP29 (Enable Digital Input)
    ldr r1, =PADS_BASE
    mov r0, #0x72             // 12mA drive + Input Enable
    str r0, [r1, #0x78]        // GP29 PAD register

    // 2. Configure PADS for 12mA drive
    ldr r0, =PADS_BASE
    ldr r1, =0x72
    str r1, [r0, #0x60]        // GP23
    str r1, [r0, #0x64]        // GP24
    str r1, [r0, #0x68]        // GP25
    str r1, [r0, #0x78]        // GP29

    // 3. Set Function to SIO (5)
    ldr r0, =IO_BANK0_BASE
    add r0, #0x80
    movs r1, #5
//    str r1, [r0, #0xbc]        // GP23 (Control REG_ON)
//    str r1, [r0, #0xc4]        // GP24 (Data)
//    str r1, [r0, #0xcc]        // GP25 (CS)
//    str r1, [r0, #0xec]        // GP29 (Clock)

    str r1, [r0, #0x3c]        // GP23 (Control REG_ON)
    str r1, [r0, #0x44]        // GP24 (Data)
    str r1, [r0, #0x4c]        // GP25 (CS)
    str r1, [r0, #0x6c]        // GP29 (Clock)

    // --- STEP 4: RIGID POWER-UP STRAP ---
    ldr r1, =SIO_BASE

    // a. Set initial pin states (GP24 Data=Low, GP25 CS=High, GP29 Clock=Low)
    ldr r2, =GP25_CS           // 1 << 25
    str r2, [r1, #0x14]        // Atomic Set CS High
    ldr r2, =(GP24_DATA | GP29_CLK)
    str r2, [r1, #0x18]        // Atomic Clear Data/Clock Low

    // b. Enable Output Drivers for these 3 pins
    ldr r2, =(GP24_DATA | GP25_CS | GP29_CLK | GP23_REG_ON)
    str r2, [r1, #0x24]        // OE_SET (Enable Output Enable)

    // c. Brief wait for pins to settle (important for electrical stability)
    mov r0, #255
1:  sub r0, #1; bne 1b

    // d. Pulse Power High (GP24 must remain Low here to strap SPI mode)
    ldr r2, =GP23_REG_ON
    str r2, [r1, #0x14]        // WL_REG_ON High

    // e. Mandatory Startup Delay (min 10-20ms for chip oscillator)
    ldr r0, =2500000           // Increased delay for 125MHz clock
    bl  delay_cycles

    // 5. Sync the Bus
    ldr r0, =CMD_SYNC
    bl  write_transaction

    nop

    ldr r0, =CMD_SYNC
    bl  write_transaction       // sync again...

//    ldr r0, =1000000           // Start-up delay
//    bl  delay_cycles

    // --- DIAGNOSTIC CHECK START ---
    bl  check_spi_id           // R0 will now contain the ID

    // Comparison: Check if R0 == 0xFEEDBEAD
    ldr r1, =0xFEEDBEAD
    cmp r0, r1
    beq spi_success            // If equal, move to Step 6

stop_here:
    b   stop_here

spi_success:
    // 6. Enable LED Output
    ldr r0, =CMD_LED_EN
    ldr r1, =0x01000000        // Set Bit 24 (WL_GPIO0)
    bl  write_register

main_loop:
    ldr r0, =CMD_LED_WRITE
    //ldr r1, =0x01000000        // LED ON
    mov r1, #1              // LED ON
    bl  write_register
    ldr r0, =3000000
    bl  delay_cycles

led_off:
    ldr r0, =CMD_LED_WRITE
    ldr r1, =0x00000000        // LED OFF
    bl  write_register
    ldr r0, =3000000
    bl  delay_cycles
    b   main_loop

// --- Subroutines ---

write_register:
    push {r4, lr}
    mov r4, r1
    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #0x18]        // CS Low
    
    bl  shift_out_32           // Send Command

    // Mandatory Turnaround Cycle
    ldr r3, =GP29_CLK
    str r3, [r1, #0x14]        // Clock High
    nop
    str r3, [r1, #0x18]        // Clock Low

    mov r0, r4
    bl  shift_out_32           // Send Data
    
    ldr r2, =GP25_CS
    str r2, [r1, #0x14]        // CS High
    pop {r4, pc}

write_transaction:
    push {lr}
    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #0x18]        // CS Low
    bl  shift_out_32
    str r2, [r1, #0x14]        // CS High
    pop {pc}

shift_out_32:
    ldr r1, =SIO_BASE
    ldr r2, =GP24_DATA
    ldr r3, =GP29_CLK
    movs r4, #32
bit_loop:
    lsr  r0, #1                // SHIFT RIGHT (LSB FIRST)
    bcc  low
    str r2, [r1, #0x14]        // Data High
    b    pulse
low:
    str r2, [r1, #0x18]        // Data Low
pulse:
    str r3, [r1, #0x14]        // Clock High
    nop
    nop
    str r3, [r1, #0x18]        // Clock Low
    sub  r4, #1
    bne  bit_loop
    bx   lr

delay_cycles:
    sub  r0, #1
    bne  delay_cycles
    bx   lr

// Command to Read address 0x14 (Read Test Register)
// Format: 0x00000000 | (0x14 << 2) | (0 << 30) for Read
// In 32-bit LSB-first: 0x14000000 (standard read command)
.equ CMD_READ_TEST, 0x14000000

check_spi_id:
    push {r4, lr}
    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #0x18]        // CS Low (Active)

    // 1. Send Read Command
    ldr r0, =CMD_READ_TEST
    bl  shift_out_32

    // 2. Change GP24 to Input for receiving data
    ldr r2, =GP24_DATA
    str r2, [r1, #0x28]        // OE_CLR (Set GP24 to Input)

    // 3. Turnaround Cycle (Mandatory 1 clock pulse)
    ldr r3, =GP29_CLK
    str r3, [r1, #0x14]        // Clock High
    nop
    str r3, [r1, #0x18]        // Clock Low

    // 4. Capture 32-bit Response
    bl  shift_in_32            // Returns value in R0
    mov r4, r0                 // Store result in R4 for inspection

    // 5. Restore GP24 to Output
    str r2, [r1, #0x24]        // OE_SET
    ldr r2, =GP25_CS
    str r2, [r1, #0x14]        // CS High (Idle)

    mov r0, r4                 // Return the ID in R0
    pop {r4, pc}

// shift_in_32:
shift_in_32:
    ldr r1, =SIO_BASE
    ldr r2, =GP24_DATA
    ldr r3, =GP29_CLK
    mov r4, #32
    mov r5, #0                // Build result here

in_loop:
    str r3, [r1, #0x14]        // Clock High
    nop
    ldr r6, [r1, #0x04]        // Read SIO_IN (Pin Status)
    lsr r5, #1                // Shift result right (building LSB-first)
    tst r6, r2                 // Is GP24 High?
    beq bit_low
    ldr r6, =0x80000000        // Set top bit if pin is high
    orr r5, r6

bit_low:
    str r3, [r1, #0x18]        // Clock Low
    sub r4, #1
    bne in_loop
    mov r0, r5
    bx  lr

.equ ADC_BASE,    0x4004c000
.equ RESETS_BASE, 0x4000c000

check_vsys_power:
    push {lr}
    // 1. Release ADC from Reset
    ldr r0, =0x4000f000     // Atomic Clear
    mov r1, #1              // ADC is bit 0
    str r1, [r0]

wait_adc_ready:
    ldr r0, =RESETS_BASE
    ldr r2, [r0, #8]
    tst r2, r1
    beq wait_adc_ready      // Wait for reset done

    // 2. Enable ADC Power
    ldr r0, =ADC_BASE
    mov r1, #1              // EN bit
    str r1, [r0, #0x00]     // CS register
2:  ldr r2, [r0, #0x00]
    mov r3, #1              // READY bit
    lsl r3, #8
    tst r2, r3
    beq 2b                  // Wait for ADC ready

.equ CLOCKS_BASE, 0x40008000

setup_adc_clock:
    ldr r0, =CLOCKS_BASE

    // CLK_ADC_CTRL is at offset 0x60
    // We want to set AUXSRC (bits 5-7) to 0 (pll_usb)
    // and enable the clock (bit 11)

    // disable the clock to clear any bad state:
    mov r1, #0
    str r1, [r0, #0x60]

    // configure: AUXSRC=0, ENABLE=1
    ldr r1, =(1 << 11)         // ENABLE bit
    str r1, [r0, #0x60]        // Set ADC clock to pll_usb and Enable

    // Wait for the clock to be running (optional but safe)
1:  ldr r1, [r0, #0x60]
    lsr r1, #12
    tst r1, r1
    mov r2, #100
2:  sub r2, #1
    bne 2b

    bx lr

# EOF:
