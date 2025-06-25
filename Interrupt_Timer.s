;------------------------------------------------------------------------------
; Purpose: Interrupt-based LED timer using ARMv7 Assembly on LPC1768
;------------------------------------------------------------------------------
                THUMB                               ; Use Thumb instruction set
                AREA    My_code, CODE, READONLY     ; Define code section
                EXPORT  __MAIN                      ; Entry label for linker
                EXPORT  EINT3_IRQHandler            ; Export ISR handler
                ENTRY

__MAIN
;------------------------------------------------------------------------------
; Section 1: Initialize GPIO and disable all LEDs
;------------------------------------------------------------------------------
                LDR     R10, =LED_BASE_ADR          ; Load base address for GPIO LEDs into R10
                MOV     R3, #0xB0000000             ; Turn off 3 LEDs on Port 1
                STR     R3, [R10, #0x20]            ; Write to Port 1 (offset 0x20)
                MOV     R3, #0x0000007C             ; Turn off 5 LEDs on Port 2
                STR     R3, [R10, #0x40]            ; Write to Port 2 (offset 0x40)

                MOV     R11, #0xABCD                ; Initialize LFSR seed (non-zero)

;------------------------------------------------------------------------------
; Section 2: Main loop to blink LEDs until interrupt
;------------------------------------------------------------------------------
LOOP            BL      RNG                         ; Generate pseudo-random number into R11
                MOV     R6, #1                      ; Flag used to detect interrupt

                LDR     R3, =ISER0
                MOV     R2, #0x00200000
                STR     R2, [R3]                    ; Enable interrupt for EINT3

                LDR     R3, =IO2IntEnf
                MOV     R2, #0x00000400
                STR     R2, [R3]                    ; Enable falling edge interrupt for P2.10 (INT0)

                MOV     R9, #0                      ; Reset timer counter

TIMER_loop      TEQ     R6, #0                      ; Check if interrupt occurred
                MOV     R3, #0x00000000
                STR     R3, [R10, #0x20]            ; Turn on Port 1 LEDs
                STR     R3, [R10, #0x40]            ; Turn on Port 2 LEDs
                MOV     R0, #1
                BL      DELAY                       ; Delay 100ms

                MOV     R3, #0xF0000000             ; Turn off Port 1 LEDs
                STR     R3, [R10, #0x20]
                MOV     R3, #0x000000FF             ; Turn off Port 2 LEDs
                STR     R3, [R10, #0x40]
                MOV     R0, #1
                BL      DELAY                       ; Delay 100ms

                ADD     R9, #1                      ; Increment timer counter
                B       TIMER_loop

;------------------------------------------------------------------------------
; RNG: Generate 16-bit pseudo-random number using LFSR (Fibonacci style)
;------------------------------------------------------------------------------
RNG             STMFD   R13!,{R1-R3, R14}
                AND     R1, R11, #0x8000
                AND     R2, R11, #0x2000
                LSL     R2, #2
                EOR     R3, R1, R2
                AND     R1, R11, #0x1000
                LSL     R1, #3
                EOR     R3, R3, R1
                AND     R1, R11, #0x0400
                LSL     R1, #5
                EOR     R3, R3, R1
                LSR     R3, #15
                LSL     R11, #1
                ORR     R11, R11, R3
                LDMFD   R13!,{R1-R3, R15}

;------------------------------------------------------------------------------
; DELAY: Delay of 100ms * R0 iterations (approximate)
;------------------------------------------------------------------------------
DELAY           STMFD   R13!,{R2, R14}
MultipleDelay   TEQ     R0, #0
                MOV     R4, #0x08D5
                MOVT    R4, #0x0002                 ; R4 = 0x000208D5 (~133333 cycles)
loop            SUBS    R4, #1
                BNE     loop
                SUBS    R0, #1
                BEQ     exitDelay
                BNE     MultipleDelay
exitDelay       LDMFD   R13!,{R2, R15}

;------------------------------------------------------------------------------
; DISPLAY_NUM: Displays value in R3 across both LED ports
;------------------------------------------------------------------------------
DISPLAY_NUM     STMFD   R13!,{R1, R2, R14}
                MOV     R5, #0
                BFI     R5, R3, #0, #5              ; Extract lower 5 bits for P2
                RBIT    R5, R5
                LSR     R5, #25
                LSR     R3, #5
                EOR     R5, #0xFFFFFFFF
                STR     R5, [R10, #0x40]

                MOV     R5, #0
                BFI     R5, R3, #0, #1              ; Extract bit 0 for P1
                LSL     R3, #1
                ADD     R3, R5
                BFI     R5, R3, #0, #4
                RBIT    R5, R5
                EOR     R5, #0xFFFFFFFF
                STR     R5, [R10, #0x20]

                LDMFD   R13!,{R1, R2, R15}

;------------------------------------------------------------------------------
; EINT3_IRQHandler: Interrupt Service Routine for INT0 button press
;------------------------------------------------------------------------------
EINT3_IRQHandler STMFD   R13!, {R4, R5, R14}
                BL      RNG                         ; Generate random number
                MOV     R0, R11
                MOV32   R2, #201
                UDIV    R1, R0, R2
                MUL     R2, R1
                SUB     R0, R11, R2
                ADD     R0, #50                     ; Scale to 50–250 range
                MOV     R6, R0

DISPLAY_LED     CMP     R6, #0
                BEQ     exitDISPLAY_LED
                MOV     R3, R6
                BL      DISPLAY_NUM
                MOV     R0, #10
                BL      DELAY
                SUBS    R6, #10
                BGT     DISPLAY_LED

exitDISPLAY_LED LDR     R5 , =IO2IntClr
                MOV     R4, #0x400
                STR     R4, [R5]                    ; Clear INT0 interrupt
                LDMFD   R13!, {R4, R5, R15}

;------------------------------------------------------------------------------
; Useful constants and hardware addresses
;------------------------------------------------------------------------------
LED_BASE_ADR    EQU     0x2009C000
PINSEL3         EQU     0x4002C00C
PINSEL4         EQU     0x4002C010
FIO1DIR         EQU     0x2009C020
FIO2DIR         EQU     0x2009C040
FIO1SET         EQU     0x2009C038
FIO2SET         EQU     0x2009C058
FIO1CLR         EQU     0x2009C03C
FIO2CLR         EQU     0x2009C05C
IO2IntEnf       EQU     0x400280B4
IO2IntClr       EQU     0x400280AC
ISER0           EQU     0xE000E100

                ALIGN
                END