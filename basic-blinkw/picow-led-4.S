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

    @ Set default idle states: CS high, CLK low
    ldr r0, =(1 << CS_PIN)
    str r0, [r6, #SIO_GPIO_OUT_SET_OFFSET]
    ldr r0, =(1 << CLK_PIN)
    str r0, [r6, #SIO_GPIO_OUT_CLR_OFFSET]

    @ --- Step 3: Enable LED Output on CYW43 ---
    @ We need to write 0x00000001 to ChipCommon GPIO_OUT_EN (Address 0x18000060)
    @ gSPI Header for Write, Func 1, Addr 0x18000060, Length 4 bytes:
    @ Bit 31=1 (Write), Bit 30=1 (Inc), Bits 29:28=01 (Func 1), Bits 27:11=0x18000060 offset...
    @ Pre-calculated Little-Endian 32-bit Header for this specific write transaction:
    ldr r1, =0xB00C0004   
    ldr r2, =0x00000001   @ Payload: Enable Pin 0
    bl send_gspi_packet

    @ --- Step 4: Turn the LED ON ---
    @ We need to write 0x00000001 to ChipCommon GPIO_OUT (Address 0x1800005C)
    @ Pre-calculated Little-Endian 32-bit Header for this transaction:
    ldr r1, =0xB00B8004   
    ldr r2, =0x00000001   @ Payload: Turn Pin 0 HIGH
    bl send_gspi_packet

infinite_loop:
    b infinite_loop

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

delay_ms:
    ldr r4, =500000
delay_loop:
    sub r4, #1
    bne delay_loop
    bx lr

// EOF:
