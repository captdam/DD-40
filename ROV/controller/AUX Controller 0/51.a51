; Software SPI slave updating P0, P1, P3
; MSB first
; P2 first, then P1, then P0
; Sample at SCLK rising edge (SPI mode3)

;SFR - STC89C52RC
	XICON		EQU	0xC0
	T2CON		EQU	0xC8
	T2MOD		EQU	0xC9
	RCAP2L		EQU	0xCA
	RCAP2H		EQU	0xCB
	TL2		EQU	0xCC
	TH2		EQU	0xCD
	WDT_CONTR	EQU	0xE1
	ISP_DATA	EQU	0xE2
	ISP_ADDRH	EQU	0xE3
	ISP_ADDRL	EQU	0xE4
	ISP_CMD		EQU	0xE5
	ISP_TRIG	EQU	0xE6
	ISP_CONTR	EQU	0xE7
	P4		EQU	0xE8
	
	ET2		EQU	IE.5
	TF2		EQU	T2CON.7
	EXF2		EQU	T2CON.6
	RCLK		EQU	T2CON.5
	TCLK		EQU	T2CON.4
	EXEN2		EQU	T2CON.3
	TR2		EQU	T2CON.2
	C_T2		EQU	T2CON.1
	CP_RL2		EQU	T2CON.0

;App config
	SCLK		EQU	P3.2
	SS		EQU	P3.3
	SDI		EQU	P3.4
	SDO		EQU	P3.5
	
	DATA_P2		EQU	0x32
	DATA_P1		EQU	0x31
	DATA_P0		EQU	0x30			;not used
		
	SYSCLK		EQU	10000			;*100
	BAUD		EQU	24			;*100
	UART_RELOAD	EQU	-(SYSCLK/BAUD/32)	;Crys = 12M, Baud = 2400, Mode = 1 (no parrty)
	
;Interrupt vector map
ORG	0x0000
	JMP	INI
ORG	0x0003
	JMP	INT_0
ORG	0x000B
	JMP	TIMER_0
ORG	0x0013
	JMP	INT_1
ORG	0x001B
	JMP	TIMER_1
ORG	0x0023
	JMP	UART
ORG	0x002B
	JMP	TIMER_2

; MAIN CODE --------------------------------------------

INI:							;Boot setup
	MOV	SP, #0x7F
	
	MOV	P0, #0x00				;All output pins set to low (MOSFET turned off)
	MOV	P1, #0x00
	MOV	P2, #0x00
	MOV	P3, #0xFF				;Communication/Control IO pull high
	
;	SETB	EX1					;Enable INT1 (P3.3, SS), on falling trigger
;	SETB	IT1
		
	MOV	SCON, #0x40				;UART mode1 (8-bit, flex baud), disable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 to 16-bit normal
	SETB	TR1					;Enable timer1 running
	SETB	ET0					;Enable timer0 interrupt
	SETB	EA

IDEL:							;Wait for command
;	MOV	PCON, #0x20				;Chip powerdown
;	JMP	$					;Busy wait until power down. Power-up by interrupt, PC will be moved to next line in the interrupt
	JB	SS, $;;;;;;;;;;;;
	SETB	P0.7
	CALL	INT_1
	CLR	P0.7
	JMP	IDEL
	
	

; INTERRUPT SUBROUTINE ---------------------------------

INT_0:
	RETI

TIMER_0:
	CLR	TF0
	RETI

INT_1:							;Chip select (for faster response, using busy wait without subroutine)
	CLR	A
	
	spi_27:						;Data: byte2, bit7
	JB	SS, spi_2_jumper_end			;SS unselected, end of transcation
	JNB	SCLK, spi_27				;Wait for SCLK rising edge
	JNB	SDI, spi_27_low				;Read SPI data
	INC	A					;Read into ACC (0 by default)
	spi_27_low:	RL	A			;Go to next bit
	
	spi_26:						;Data: byte2, bit6
	JB	SS, spi_2_jumper_end
	JNB	SCLK, spi_26
	JNB	SDI, spi_26_low
	INC	A
	spi_26_low:	RL	A
	
	spi_25:
	JB	SS, spi_2_jumper_end
	JNB	SCLK, spi_25
	JNB	SDI, spi_25_low
	INC	A
	spi_25_low:	RL	A
	
	spi_24:
	JB	SS, spi_2_jumper_end
	JNB	SCLK, spi_24
	JNB	SDI, spi_24_low
	INC	A
	spi_24_low:	RL	A
	
	spi_23:
	JB	SS, spi_2_jumper_end
	JNB	SCLK, spi_23
	JNB	SDI, spi_23_low
	INC	A
	spi_23_low:	RL	A
	
	spi_22:
	JB	SS, spi_2_jumper_end
	JNB	SCLK, spi_22
	JNB	SDI, spi_22_low
	INC	A
	spi_22_low:	RL	A
	
	spi_21:
	JB	SS, spi_2_jumper_end
	JNB	SCLK, spi_21
	JNB	SDI, spi_21_low
	INC	A
	spi_21_low:	RL	A
	
	spi_20:
	JB	SS, spi_2_jumper_end
	JNB	SCLK, spi_20
	JNB	SDI, spi_20_low
	INC	A
	spi_20_low:
	
	MOV	DATA_P2, A
	CLR	A
	JMP	spi_2_jumper_continuous
	
	SETB	P0.2
	
	MOV	SBUF, A
	
	spi_2_jumper_end:				;JB cannot jump too far
	JMP	spi_end
	spi_2_jumper_continuous:
	
	spi_17:						;Data: byte1
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_17
	JNB	SDI, spi_17_low
	INC	A
	spi_17_low:	RL	A
	
	spi_16:
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_16
	JNB	SDI, spi_16_low
	INC	A
	spi_16_low:	RL	A
	
	spi_15:
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_15
	JNB	SDI, spi_15_low
	INC	A
	spi_15_low:	RL	A
	
	spi_14:
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_14
	JNB	SDI, spi_14_low
	INC	A
	spi_14_low:	RL	A
	
	spi_13:
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_13
	JNB	SDI, spi_13_low
	INC	A
	spi_13_low:	RL	A
	
	spi_12:
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_12
	JNB	SDI, spi_12_low
	INC	A
	spi_12_low:	RL	A
	
	spi_11:
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_11
	JNB	SDI, spi_11_low
	INC	A
	spi_11_low:	RL	A
	
	spi_10:
	JB	SS, spi_1_jumper_end
	JNB	SCLK, spi_10
	JNB	SDI, spi_10_low
	INC	A
	spi_10_low:
	
	MOV	DATA_P1, A
	CLR	A
	JMP	spi_1_jumper_continuous
	
	spi_1_jumper_end:				;JB cannot jump too far
	JMP	spi_end
	spi_1_jumper_continuous:
	
	spi_07:
	JB	SS, spi_end
	JNB	SCLK, spi_07
	JNB	SDI, spi_07_low
	INC	A
	spi_07_low:	RL	A
	
	spi_06:
	JB	SS, spi_end
	JNB	SCLK, spi_06
	JNB	SDI, spi_06_low
	INC	A
	spi_06_low:	RL	A
	
	spi_05:
	JB	SS, spi_end
	JNB	SCLK, spi_05
	JNB	SDI, spi_05_low
	INC	A
	spi_05_low:	RL	A
	
	spi_04:
	JB	SS, spi_end
	JNB	SCLK, spi_04
	JNB	SDI, spi_04_low
	INC	A
	spi_04_low:	RL	A
	
	spi_03:
	JB	SS, spi_end
	JNB	SCLK, spi_03
	JNB	SDI, spi_03_low
	INC	A
	spi_03_low:	RL	A
	
	spi_02:
	JB	SS, spi_end
	JNB	SCLK, spi_02
	JNB	SDI, spi_02_low
	INC	A
	spi_02_low:	RL	A
	
	spi_01:
	JB	SS, spi_end
	JNB	SCLK, spi_01
	JNB	SDI, spi_01_low
	INC	A
	spi_01_low:	RL	A
	
	spi_00:
	JB	SS, spi_end
	JNB	SCLK, spi_00
	JNB	SDI, spi_00_low
	INC	A
	spi_00_low:
	
	MOV	P2, DATA_P2
	MOV	P1, DATA_P1
	MOV	P0, A
	
	spi_end:
	;RETI;;;;;;;;;;;;;;;
	RET

TIMER_1:
	CLR	TF1
	RETI

UART:
	CLR	TI
	CLR	RI
	RETI

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; INTERNAL FUNCTIONS -----------------------------------


; EXTERNAL FUNCTIONS -----------------------------------


; CONSTANT DATA TABLES ---------------------------------



END;
