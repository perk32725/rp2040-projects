// --- Constants ---
.equ RESETS_BASE,      0x4000c000
.equ IO_BANK0_BASE,    0x40014000
.equ PADS_BASE,        0x4001c000
.equ SIO_BASE,         0xd0000000

.equ ASET,   0x14
.equ ACLR,   0x18
.equ OE_SET, 0x24
.equ OE_CLR, 0x28

// Pins for Pico W SPI to CYW43439
.equ GP23_REG_ON, (1 << 23)
.equ GP24_DATA,   (1 << 24)
.equ GP25_CS,     (1 << 25)
.equ GP29_CLK,    (1 << 29)

// 3-Wire SPI Commands (Big-Endian format for the wireless chip)
.equ CMD_SYNC,      0x00000400  // Estabishes 32-bit SPI mode
#.equ CMD_SYNC,      0x00040000  // Estabishes 32-bit SPI mode
.equ CMD_LED_EN,    0x900c8804  // Enable WL_GPIO0 as Output
.equ CMD_LED_WRITE, 0x900c8004  // Set WL_GPIO0 state

.thumb_func
.global _start
.global main

_start:
main:

.equ pll_usb_base, 0x4002c000
.equ pll_usb_aclr, 0x4002f000  // Atomic set alias

.global setup_pll_usb
setup_pll_usb:
    // release PLL_USB from reset:
    ldr r1, =0x4000f000     // reset atomic_clear
    ldr r2, =(1 << 13)      // bit 13 is PLL_USB
    mov r3, r2              // save a copy
    str r2, [r1]            // clear PLL_USB reset

1:  ldr r1, =RESETS_BASE    // reset control
    ldr r2, [r1, #0x08]     // see if reset is done
    tst r2, r3              // check bit 13; PLL_USB
    beq 1b                  // goes set when done

    ldr r0, =pll_usb_base
    mov r1, #1
    str r1, [r0]            // set divider to 1

    // 1. Set Feedback Divider to 100
    mov r1, #100
    str r1, [r0, #0x08]     // PLL_USB_FBDIV_INT register

    ldr r1, =pll_usb_aclr        
    mov r2, #0x21           // PD, VCOPD (pg 235)
    str r2, [r1, #0x04]     // hit the power control

    // 3. Wait for PLL Lock (Bit 31 of CS register)
wait_pll_usb_lock:          // r0 = pll_usb_base
    ldr r1, [r0, #0x00]     // PLL_USB_CS
    lsl r1, #1               
    bcc wait_pll_usb_lock   // wait for PLL locked

    // 4. Set Post Dividers (5 and 5)
    ldr r1, =((5 << 16) | (5 << 12)) 
    str r1, [r0, #0x10]     // PLL_USB_PRIM

    // 5. Power on Post Dividers (Clear bit 3 in PLL_USB_PWR)
    ldr r2, =pll_usb_aclr
    mov r3, #(1 << 3)
    str r3, [r2, #0x04]     // hit the power contol for post-divider

    // 1. Reset IO and PADS
    ldr r0, =0x4000f000     // Resets atomic clear
    ldr r1, =((1 << 8) | (1 << 21)) // PADS_BANK0 and TIMER
    str r1, [r0]            // clear them

wait_reset:
    ldr r0, =RESETS_BASE
    ldr r2, [r0, #8]        // RESET_DONE
    tst r2, r1              // are they both clear?
    beq wait_reset          // wait until done

configure:
    // 2. Configure PADS for 12mA drive
    ldr r0, =PADS_BASE
    ldr r1, =0x72
    str r1, [r0, #0x60] // GP23
    str r1, [r0, #0x64] // GP24
    str r1, [r0, #0x68] // GP25
    str r1, [r0, #0x78] // GP29

set_func_5:
    // 3. Set Function to SIO (5)
    ldr r0, =IO_BANK0_BASE
    add r0, #0x80   // add offset so we can reach with immediate offset
    mov r1, #5      // function 5 = sio

    str r1, [r0, #0x3c] // GP23 (Control REG_ON) was str r1, [r0, #0xbc]
    str r1, [r0, #0x44] // GP24 (Data)           was str r1, [r0, #0xc4]
    str r1, [r0, #0x4c] // GP25 (CS)             was str r1, [r0, #0xcc]
    str r1, [r0, #0x6c] // GP29 (Clock)          was str r1, [r0, #0xec]

power_up:
    // --- STEP 4: RIGID POWER-UP STRAP ---
    ldr r1, =SIO_BASE           // start at SIO base

pin_states:
    // a. Set initial pin states (GP24 Data=Low, GP25 CS=High, GP29 Clock=Low)
    ldr r2, =GP25_CS           // 1 << 25
    str r2, [r1, #ASET]        // CS high
    ldr r2, =(GP24_DATA | GP29_CLK)
    str r2, [r1, #ACLR]        // Data and Clock low

output_enable:
    // b. Enable Outputs for these 4 pins
    ldr r2, =(GP24_DATA | GP25_CS | GP29_CLK | GP23_REG_ON)
    str r2, [r1, #OE_SET]      // 0x24 (Enable Output Enable)

    // c. Brief wait for pins to settle (important for electrical stability)
    mov r0, #255
1:  sub r0, #1
    bne 1b

power_on:
    // d. set Power High (GP24 must remain Low here to strap SPI mode)
    ldr r2, =GP23_REG_ON
    str r2, [r1, #ASET]        // atomic set WL_REG_ON High

    // e. Mandatory Startup Delay (min 10-20ms for chip oscillator)
    ldr r0, =10000000           // Increased delay for 125MHz clock
    bl  delay_cycles

sync_thing:
// --- now do the sync thing:
    // 5. Sync the Bus
    ldr r0, =CMD_SYNC
    bl  write_transaction       // sync

    ldr r0, =CMD_SYNC
    bl  write_transaction       // sync again...

    bl  init_spi_config

    ldr r0, =10000
    bl  delay_cycles

    bl  check_spi_status

check_r0_here:
    bl  init_spi_config

//    ldr r1, =SIO_BASE
    str r2, [r1, #ACLR]     // CS low

    ldr r0, =0x900c8804
    bl  shift_out_32

    ldr r3, =GP29_CLK
    str r3, [r1, #ASET]     // 0x14 is GPIO_OUT_SET
    nop
    nop
    nop
    nop
    str r3, [r1, #ACLR]     // 0x18 is GPIO_OUT_SET
    nop
    nop
    nop
    nop

    ldr r0, =0x01000000
    bl  shift_out_32

    str r2, [r1, #ASET]     // CS high

spi_success:
    // 6. Enable LED Output
    ldr r0, =CMD_LED_EN
    ldr r1, =0x01000000        // Set Bit 24 (WL_GPIO0)
    bl  write_register

main_loop:
    ldr r0, =CMD_LED_WRITE
    //ldr r1, =0x01000000     // LED ON
    mov r1, #1              // LED ON
    bl  write_register

    ldr r0, =3000000
    bl  delay_cycles

led_off:
    ldr r0, =CMD_LED_WRITE
    mov r1, #0              // LED OFF
    bl  write_register

    ldr r0, =3000000
    bl  delay_cycles

    b   main_loop

// --- Subroutines ---
// r0 = command
// r1 = data
write_register:
    push {lr}
    mov r5, r1          // save data

    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #ACLR] // CS Low

    bl  shift_out_32    // Send Command in r0

    // Mandatory Turnaround Cycle
    ldr r4, =GP29_CLK
    str r4, [r1, #ASET] // Clock High
    nop
    str r4, [r1, #ACLR] // Clock Low
    nop

    mov r0, r5          // get the data back
    bl  shift_out_32    // Send Data

    str r2, [r1, #ASET] // CS High

    pop {pc}

//-------------------------------------------------------------
// set r1 to SIO_BASE
//     r2 to GP25_CS
//     r3 to GP24_DATA
//     r4 to GP29_CLK

write_transaction:
    push {lr}
    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #ACLR]        // CS Low

    bl  shift_out_32

    str r2, [r1, #ASET]        // CS High
    pop {pc}

//-------------------------------------------------------------
// r0 = data
shift_out_32:
    ldr r3, =GP24_DATA  // data pin
    ldr r4, =GP29_CLK   // clock pin
    mov r5, #32         // doing 32 bits

bit_loop:
    lsr  r0, #1         // SHIFT RIGHT (LSB FIRST)
    bcc  low

    str r3, [r1, #ASET] // Data High
    b    pulse

low:
    str r3, [r1, #ACLR] // Data Low
    nop

pulse:
    str r4, [r1, #ASET] // Clock High
    nop
    nop
    nop
    nop
    str r4, [r1, #ACLR] // Clock Low
    nop
    nop
    nop
    nop
    sub  r5, #1
    bne  bit_loop

    bx   lr

//-------------------------------------------------------------
delay_cycles:
    sub  r0, #1
    bne  delay_cycles
    bx   lr

// Command to Read address 0x14 (Read Test Register)
// Format: 0x00000000 | (0x14 << 2) | (0 << 30) for Read
// In 32-bit LSB-first: 0x14000000 (standard read command)
#.equ CMD_READ_TEST, 0x20000014
#.equ CMD_READ_TEST, 0x14000000
#.equ CMD_READ_TEST, 0x000050a0
.equ CMD_READ_TEST, 0x000050b1
#.equ CMD_READ_TEST, 0xb1500000

//-------------------------------------------------------------
check_spi_status:
    push {lr}
    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #ACLR]     // CS Low (Active)

    // 1. Send Command (Function 0, Read, Address 0)
    mov r0, #0              // Command 0x00000000
    bl  shift_out_32

    // 2. Switch GP24 to Input
    ldr r2, =GP24_DATA
    str r2, [r1, #OE_CLR]   // 0x28

    // enable pull-up:
    ldr r0, =PADS_BASE
    mov r1, #0x7a
    str r1, [r0, #0x64]
    ldr r1, =SIO_BASE

//    // 3. NO Turnaround needed for Function 0
//    // Pulse turnaround loop count: 0

    // --- 5-pulse turnaround:
    // 3. Turnaround Cycle (Mandatory 5 clock pulse)
    ldr r3, =GP29_CLK
    mov r4, #8      // try 6 and 7; 5 gives 0x30303030; 6 gives 0x18181818; 7 gives 0xc0c0c0c

turn_loop:
    str r3, [r1, #ASET] // Clock High

    mov r0, #10
1:  sub r0, #1
    bne 1b

    str r3, [r1, #ACLR] // Clock Low

    mov r0, #10
2:  sub r0, #1
    bne 2b

    sub r4, #1
    bne turn_loop

    // 4. Capture 32-bit Response
    bl   shift_in_32    // Result in R0
    
    // 5. Cleanup
    str r2, [r1, #OE_SET]   // 0x24
    ldr r2, =GP25_CS
    str r2, [r1, #ASET]     // CS High (Idle)
    pop {pc}

check_spi_id:
    push {r4, lr}
    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #ACLR]        // CS Low (Active)

    // 1. Send Read Command
    ldr r0, =CMD_READ_TEST
    bl  shift_out_32

    str r2, [r1, #ASET]
    ldr r0, =1000
    bl  delay_cycles

    // 2. Change GP24 to Input for receiving data
    ldr r2, =GP24_DATA
    str r2, [r1, #OE_CLR]      // 0x28 (Set GP24 to Input)

//    // enable pull-up:
//    ldr r0, =PADS_BASE
//    mov r1, #0x7a
//    str r1, [r0, #0x64]
//    ldr r1, =SIO_BASE

    // --- 5-pulse turnaround:
    // 3. Turnaround Cycle (Mandatory 5 clock pulse)
    ldr r3, =GP29_CLK
    mov r4, #7      // try 6 and 7; 5 gives 0x30303030; 6 gives 0x18181818; 7 gives 0xc0c0c0c

turnaround_loop:
    str r3, [r1, #ASET]        // Clock High

    mov r0, #10
1:  sub r0, #1
    bne 1b

    str r3, [r1, #ACLR]        // Clock Low

    mov r0, #10
2:  sub r0, #1
    bne 2b

    sub r4, #1
    bne turnaround_loop

    // 4. Capture 32-bit Response
    bl  shift_in_32            // Returns value in R0
    mov r4, r0                 // Store result in R4 for inspection

    // 5. Restore GP24 to Output
    str r2, [r1, #OE_SET]      // 0x24
    ldr r2, =GP25_CS
    str r2, [r1, #ASET]        // CS High (Idle)

    mov r0, r4                 // Return the ID in R0
    pop {r4, pc}

// shift_in_32:
shift_in_32:
    ldr r1, =SIO_BASE
    ldr r2, =GP24_DATA
    ldr r3, =GP29_CLK
    mov r4, #32
    mov r5, #0          // Build result here

in_loop:
    str r3, [r1, #ASET] // Clock High

    mov r6, #40
1:  sub r6, #1
    bne 1b

    ldr r6, [r1, #0x04] // Read SIO_IN (Pin Status)
    lsr r5, #1          // Shift result right (building LSB-first)
    tst r6, r2          // Is GP24 High?
    beq bit_low

    ldr r6, =0x80000000 // Set top bit if pin is high
    orr r5, r6

bit_low:
    str r3, [r1, #ACLR]        // Clock Low

    mov r6, #40
2:  sub r6, #1
    bne 2b

    sub r4, #1
    bne in_loop
    mov r0, r5
    bx  lr

.equ ADC_BASE,    0x4004c000
.equ RESETS_BASE, 0x4000c000

check_vsys_power:
    push {lr}
    // 1. Release ADC from Reset
    ldr r0, =0x4000f000     // Reset Atomic Clear
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

# .equ CMD_WRITE_CONFIG, 0x0000b04c  // Write to SPI Config Register
# .equ VAL_CONFIG_DATA,  0x000204b3  // Disable word swap + 4-bit delay

init_spi_config:
    push {lr}

    ldr r1, =SIO_BASE
    ldr r2, =GP25_CS
    str r2, [r1, #ACLR]     // CS Low

    ldr r2, =GP24_DATA
    str r2, [r1, #OE_SET]   // 0x24

    ldr r0, =0x0000b04c     // Address for Config Reg
    bl  shift_out_32

    // NO Turnaround for writes

    ldr r0, =0x000204b3        // The config data
    bl  shift_out_32

    ldr r2, =GP25_CS
    str r2, [r1, #ASET]        // CS High

    pop {pc}

# EOF:
