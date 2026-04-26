.cpu cortex-m0plus
.thumb

# Register  Address     Description
# VTOR      0xe000ed08  Vector Table Offset Register. Points to your ISR table.
# ISER      0xe000e100  Interrupt Set-Enable Register. Write a 1 to a bit to enable that IRQ.
# ICER      0xe000e180  Interrupt Clear-Enable Register. Write a 1 to disable an IRQ.
# ISPR      0xe000e200  Interrupt Set-Pending Register. Forces an interrupt in software.
# ICPR      0xe000e280  Interrupt Clear-Pending Register. Clears a pending interrupt state.
# IPR0–7    0xe000e400  Interrupt Priority Registers. Sets 2-bit priority (0–3) for each IRQ.

# The following table lists the 26 peripheral interrupts available on the RP2040:
# IRQ # Interrupt Name  Description
# 0     TIMER_IRQ_0     Hardware Timer Alarm 0
# 1     TIMER_IRQ_1     Hardware Timer Alarm 1
# 2     TIMER_IRQ_2     Hardware Timer Alarm 2
# 3     TIMER_IRQ_3     Hardware Timer Alarm 3
# 4     PWM_IRQ_WRAP    PWM Counter Wrap (all PWM slices share this)
# 5     USBCTRL_IRQ     USB Controller
# 6     XIP_IRQ         Execute-In-Place (External Flash) Cache
# 7     PIO0_IRQ_0      PIO 0 Interrupt Request Line 0
# 8     PIO0_IRQ_1      PIO 0 Interrupt Request Line 1
# 9     PIO1_IRQ_0      PIO 1 Interrupt Request Line 0
# 10    PIO1_IRQ_1      PIO 1 Interrupt Request Line 1
# 11    DMA_IRQ_0       DMA Controller Interrupt 0
# 12    DMA_IRQ_1       DMA Controller Interrupt 1
# 13    IO_IRQ_BANK0    GPIO Pin Interrupts (User GPIOs)
# 14    IO_IRQ_QSPI     QSPI Interface Interrupts
# 15    SIO_IRQ_PROC0   Processor 0 Inter-Processor Interrupt (FIFO)
# 16    SIO_IRQ_PROC1   Processor 1 Inter-Processor Interrupt (FIFO)
# 17    CLOCKS_IRQ      Clock Subsystem
# 18    SPI0_IRQ        SPI Controller 0
# 19    SPI1_IRQ        SPI Controller 1
# 20    UART0_IRQ       UART Controller 0
# 21    UART1_IRQ       UART Controller 1
# 22    ADC0_IRQ_FIFO   ADC Conversion Result Ready
# 23    I2C0_IRQ        I2C Controller 0
# 24    I2C1_IRQ        I2C Controller 1
# 25    RTC_IRQ         Real Time Clock

.section .vectors, "ax"
.global __vectors
__vectors:
  .word    _stack_top   // @ 0x10000000: Initial Stack Pointer
  .word    _reset + 1   // @ 0x10000004: Reset Handler Address

  .word    0x100001c3   // isr_nmi
  .word    0x100001c5   // isr_hardfault
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c7   // isr_svcall
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c1   // isr_invalid; Reserved, should never fire
  .word    0x100001c9   // isr_pendsv
  .word    0x100001cb   // isr_systick
  .word    0x100001cd   // interrupt_0  timer_irq_0
  .word    0x100001cd   // interrupt_1  timer_irq_1
  .word    0x100001cd   // interrupt_2  timer_irq_2
  .word    0x100001cd   // interrupt_3  timer_irq_3
  .word    0x100001cd   // interrupt_4  pwm_irq_wrap
  .word    0x100001cd   // interrupt_5  usbctrl_irq
  .word    0x100001cd   // interrupt_6  xip_irq
  .word    0x100001cd   // interrupt_7  pio0_0_irq
  .word    0x100001cd   // interrupt_8  pio0_1_irq
  .word    0x100001cd   // interrupt_9  pio1_0_irq
  .word    0x100001cd   // interrupt_10 pio1_1_irq
  .word    0x100001cd   // interrupt_11 dma_0_irq
  .word    0x100001cd   // interrupt_12 dma_1_irq
  .word    0x100001cd   // interrupt_13 gpio_io_irq
  .word    0x100001cd   // interrupt_14 qspi_io_irq
  .word    0x100001cd   // interrupt_15 sio_irq_p0
  .word    0x100001cd   // interrupt_16 sio_irq_p1
  .word    0x100001cd   // interrupt_17 clocks_irq
  .word    0x100001cd   // interrupt_18 spi0_irq
  .word    0x100001cd   // interrupt_19 spi1_irq
  .word    0x100001cd   // interrupt_20 uart0_irq
  .word    0x100001cd   // interrupt_21 uart1_irq
  .word    0x100001cd   // interrupt_22 adc_irq_fifo
  .word    0x100001cd   // interrupt_23 i2c0_irq
  .word    0x100001cd   // interrupt_24 i2c1_irq
  .word    0x100001cd   // interrupt_25 rtc_riq
  .word    0x100001cd   // interrupt_26 <reserved>
  .word    0x100001cd   // interrupt_27 <reserved>
  .word    0x100001cd   // interrupt_28 <reserved>
  .word    0x100001cd   // interrupt_29 <reserved>
  .word    0x100001cd   // interrupt_30 <reserved>
  .word    0x100001cd   // interrupt_31 <reserved>


// EOF:
