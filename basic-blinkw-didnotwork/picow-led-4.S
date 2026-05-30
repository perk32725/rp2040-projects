#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"
#include "hardware/regs/io_bank0.h"

.global main
.thumb_func

@ Pin bitmasks for SIO GPIO registers
.equ WL_ON_PIN,  23
.equ DIO_PIN,    24
.equ CS_PIN,     25
.equ CLK_PIN,    29

.equ SIO_BASE_ADDR, SIO_BASE
.equ GPIO_OUT_CLR,     0x18

//-----------------------------------------------------------------------
main:
    @ --- Step 1: Initialize RP2040 SIO GPIO Functions ---
    @ In a real setup, ensure GPIO 23, 24, 25, 29 are selected for SIO function
    @ via the IO_BANK0_GPIOx_CTRL registers.

    ldr r6, =SIO_BASE_ADDR
    
    @ Set WL_ON, CS, CLK, and DIO as outputs initially
    ldr r0, =((1 << WL_ON_PIN) | (1 << CS_PIN) | (1 << CLK_PIN) | (1 << DIO_PIN))
    str r0, [r6, #SIO_GPIO_OE_SET_OFFSET]

    @ --- Step 2: Power Cycle the CYW43439 ---
    ldr r0, =(1 << WL_ON_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]   @ WL_ON low
    bl delay_ms
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]   @ WL_ON high
    bl delay_ms

    @ =========================================================================
    @ 2. NEW CRITICAL STEP: WAKE UP THE CYW43439 CORE CLOCKS
    @ =========================================================================
    @ Write to Function 0, Address 0x1C (Device Control Reg) to request Active Clock
    @ Header: Write, Func 0, Addr 0x1C, Len 4 -> 0x0A380400
    ldr r1, =0x0A380400
    ldr r2, =0x02000000   @ Request HT (High Throughput) clock active state
    bl write_gspi_register

    @ Allow 50ms for the internal PLL clock network to stabilize and lock
    bl delay_ms
    bl delay_ms

    @ Command B: Update PMU Wake Control Register to force Core Power-Up
    @ Header: Write, Func 0, Addr 0x1E, Len 4 -> 0x0A3C0400
    ldr r1, =0x0A3C0400
    ldr r2, =0x00000080   @ Drives wake signal high
    bl write_gspi_register

    @ Allow 50ms for the internal PLL clock network to stabilize and lock
    bl delay_ms
    bl delay_ms

    @ Set default idle states: CS high, CLK low
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]

// see if we can read from the chip:
//    ldr r1, =0x400A0004
//    ldr r1, =0x04000A40
    ldr r1, =0x0A400400
    bl  read_gspi_test_register

read_r0:
    nop

@ --- STEP A: Release Pin 0 from the Hardware Multiplexer ---
    @ Header: Write, Func 1, Addr 0x18000074, Len 4 -> 0x0004B00E
    ldr r1, =0x0004B00E
    ldr r2, =0x00000000   @ Clear multiplexer bits to select software register control
    bl write_gspi_register

    @ --- STEP B: Configure Pin 0 as an Output ---
    @ Header: Write, Func 1, Addr 0x18000060, Len 4 -> 0x0004B00C
    ldr r1, =0x0004B00C
    ldr r2, =0x01000000   @ Set Bit 0 high (Swapped format for linear MSB shift)
    bl write_gspi_register

    @ --- STEP C: Drive Pin 0 HIGH (Turn LED ON) ---
    @ Header: Write, Func 1, Addr 0x1800005C, Len 4 -> 0x0004B00B
    ldr r1, =0x0004B00B
    ldr r2, =0x01000000   @ Set Bit 0 high (Swapped format for linear MSB shift)
    bl write_gspi_register

    @ --- Step A: Enable LED Output on CYW43 ---
    @ We need to write 0x00000001 to ChipCommon GPIO_OUT_EN (Address 0x18000060)
    @ gSPI Header for Write, Func 1, Addr 0x18000060, Length 4 bytes:
    @ Bit 31=1 (Write), Bit 30=1 (Inc), Bits 29:28=01 (Func 1), Bits 27:11=0x18000060 offset...
    @ Pre-calculated Little-Endian 32-bit Header for this specific write transaction:
//    ldr r1, =0xB00C0004   
//    ldr r2, =0x00000001   @ Payload: Enable Pin 0
    ldr r1, =0x0004b00c   
    ldr r2, =0x01000000   @ Payload: Enable Pin 0
    bl send_gspi_packet

    @ --- Step B: Turn the LED ON ---
    @ We need to write 0x00000001 to ChipCommon GPIO_OUT (Address 0x1800005C)
    @ Pre-calculated Little-Endian 32-bit Header for this transaction:
//    ldr r1, =0xB00B8004   
//    ldr r2, =0x00000001   @ Payload: Turn Pin 0 HIGH
    ldr r1, =0x0004B00B     @ was 0xb00b8004
    ldr r2, =0x01000000   @ was 0x00000001 Payload: Turn Pin 0 HIGH
//    bl send_gspi_packet
    bl write_gspi_register

//-----------------------------------------------------------------------
infinite_loop:
    b infinite_loop

@ --- Dedicated Write Assembly Routine ---
@ Inputs: r1 = 32-bit Command Header, r2 = 32-bit Data Payload
write_gspi_register:
    push {r4, lr}
    
    @ 1. Assert CS Low
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    nop
    nop

    @ 2. Clock out the 32-bit Header (DIO is an Output)
    movs r3, #32

write_header_loop:
    lsl r1, #1
    bcs dio_high_w

    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    b clk_pulse_w

dio_high_w:
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]

clk_pulse_w:
    nop
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]   @ CLK High
    nop
    nop
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]   @ CLK Low
    nop
    
    sub r3, #1
    bne write_header_loop

    @ 3. Small turn-around window for Backplane synchronization
    movs r3, #2

write_turn_around:
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    nop
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    nop
    sub r3, #1
    bne write_turn_around

    @ 4. Clock out the 32-bit Data Payload (MSB-first linear shift)
    movs r3, #32

write_payload_loop:
    lsl r2, #1
    bcs dio_high_wd

    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    b clk_pulse_wd

dio_high_wd:
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]

clk_pulse_wd:
    nop
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]   @ CLK High
    nop
    nop
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]   @ CLK Low
    nop
    
    sub r3, #1
    bne write_payload_loop

    @ 5. Finalize Transaction: CS High
    nop
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    nop
    
    pop {r4, pc}

//-----------------------------------------------------------------------
@ --- Bit-Bang Transmission Helper ---
@ Inputs: r1 = 32-bit Header, r2 = 32-bit Data Payload
send_gspi_packet:
    push {lr}
    
    @ Assert CS Low
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]

    @ Send Header (32 bits, MSB first)
    movs r3, #32

header_loop:
    @ Set DIO pin based on MSB of r1
    lsl r1, #1
    bcs dio_high_h

    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    b clk_pulse_h

dio_high_h:
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]

clk_pulse_h:
    @ Pulse Clock (Low -> High -> Low)
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    
    sub r3, #1
    bne header_loop

    @ Send Data Payload (32 bits, MSB first)
    movs r3, #32

payload_loop:
    lsl r2, #1
    bcs dio_high_d

    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    b clk_pulse_d

dio_high_d:
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]

clk_pulse_d:
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    
    sub r3, #1
    bne payload_loop

    @ De-assert CS High
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    
    pop {pc}

//-----------------------------------------------------------------------
delay_ms:
    ldr r4, =500000

delay_loop:
    sub r4, #1
    bne delay_loop
    bx lr

#include "hardware/regs/addressmap.h"
#include "hardware/regs/sio.h"

.global main_asm
.thumb_func

@ Pin Assignments
.equ WL_ON_PIN,  23
.equ DIO_PIN,    24
.equ CS_PIN,     25
.equ CLK_PIN,    29

.equ SIO_BASE_ADDR, SIO_BASE
/*
main_asm:
    @ --- (Keep your prior step 1 and step 2 power up/initialization routines here) ---
    ldr r6, =SIO_BASE_ADDR

    @ --- Step 3: Read the Test Pattern ---
    @ Header: Read, Func 0, Addr 0x14, Len 4 -> 0x400A0004
    ldr r1, =0x400A0004
    bl read_gspi_test_register

    @ The 32-bit test pattern result is now stored inside register R0!
    @ If the bus is healthy, R0 will contain 0xBEADFEED (or its bit-shifted alignment).

infinite_loop:
    b infinite_loop
*/

@ --- Bidirectional Read Assembly Routine ---
@ Input:  r1 = 32-bit Command Header
@ Output: r0 = 32-bit Data read from the CYW43 chip

read_gspi_test_register:
    push {r4, r5, r7, lr}

    @ 1. Assert CS Low to begin transaction
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    nop
    nop

    @ 2. Clock out the 32-bit Header (DIO is currently an Output)
    movs r3, #32

header_read_loop:
    lsl r1, #1
    bcs dio_high_rh
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    b clk_pulse_rh

dio_high_rh:
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]

clk_pulse_rh:
    nop
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    nop
    nop
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    nop
    sub r3, #1
    bne header_read_loop

    @ 3. CRITICAL: Switch RP2040 DIO Pin to an INPUT
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OE_CLR_OFFSET]
    nop
    nop

    @ 4. Generate 4 Turn-Around Dummy Clocks (CYW43 prepares the response)
    movs r3, #4

turn_around_loop:
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    nop
    nop
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    nop
    nop
    sub r3, #1
    bne turn_around_loop

    @ 5. Clock in 32-bit Data Payload from CYW43
    movs r4, #0          @ Clear r4 (this will assemble our incoming data)
    movs r7, #0

read_byte_loop:
    movs r2, #0
    movs r3, #8

read_bits_loop:
    // delay:
    nop
    nop
    nop
    nop

    @ Sample the state of the DIO Pin (GPIO 24) while clock is LOW
    ldr r5, [r6, #SIO_GPIO_IN_OFFSET]
    lsr r5, #25  @ Shift pin status into Carry bit

    @ Shift our accumulator left, and pull in the Carry bit state
    adc r2, r2

    @ Pulse Clock High to make CYW43 drive the bit
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    nop
    nop

    @ Pulse Clock Low
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]
    nop
    nop

    sub r3, #1
    bne read_bits_loop

    @ We have read 1 byte (stored in r2). Now place it into the correct position
    @ inside our 32-bit register r4 (Little Endian byte ordering).
    @ Byte 0 goes to bits 0-7, Byte 1 to bits 8-15, etc.
    movs r5, r7
    lsl  r5, #3          @ Multiply byte index by 8 to get bit shift amount
    lsl  r2, r5          @ Shift byte into position
    orr  r4, r2          @ Merge byte into our 32-bit result

    add  r7, #1
    cmp r7, #4
    bne read_byte_loop

    @ 6. Finalize Transaction: CS High
    nop
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    nop

    @ 7. Restore DIO Pin back to an OUTPUT for future writes
    ldr r0, =(1 << DIO_PIN)
    str r0, [r6, #SIO_GPIO_OE_SET_OFFSET]

    @ Move final assembled 32-bit value into return register r0
    mov r0, r4
    pop {r4, r5, r7, pc}

// EOF:
