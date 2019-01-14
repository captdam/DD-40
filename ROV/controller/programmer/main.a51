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
	SYSCLK		EQU	10000			;*100
	BAUD		EQU	24			;*100
	UART_RELOAD	EQU	-(SYSCLK/BAUD/32)	;Crys = 12M, Baud = 2400, Mode = 1 (no parrty)
		
	MISO		EQU	P3.4
	MOSI		EQU	P3.5
	SCLK		EQU	P3.6
	SS		EQU	P3.7
	
	SPI_WORDSIZE	EQU	0x04
	SPI_WORDCOUNTER	EQU	0x30
	
	
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
	
	MOV	SCON, #0x40				;UART mode1 (8-bit, flex baud), disable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 to 16-bit normal
	SETB	TR1					;Enable timer1 running
	SETB	ET0					;Enable timer0 interrupt
	SETB	EA
	
	SETB	SS

MAIN:
	MOV	DPTR, #string_mcu_ready			;Pointer to string data: MCU Ready
	CALL	FUNC_UART_SEND_STRING
	MOV	SPI_WORDCOUNTER, #0x01
	JMP	IDEL
	
	string_mcu_ready:	DB	"SPI interface ready!",13,10,0

IDEL:							;Wait for command
	MOV	DPTR, #string_system_ready
	CALL	FUNC_UART_SEND_STRING
	
	SETB	REN					;Enable UART Rx, idel
	JMP	$					;Wait input
	CLR	REN					;Stop listen, busy
	
	MOV	R7, SBUF				;Get data from PC
	MOV	DPTR, #string_spi_send
	CALL	FUNC_UART_SEND_STRING
	MOV	A, R7
	CALL	FUNC_UART_SEND_HEXCHAR
	
	DJNZ	SPI_WORDCOUNTER, ssnotset		;Reset SPI if reach word count
	MOV	SPI_WORDCOUNTER, #SPI_WORDSIZE
	SETB	SS
	NOP
	NOP
	CLR	SS
	ssnotset:
	
	MOV	A, R7					;Send data to SPI
	CALL	FUNC_SPI
	
	MOV	R7, A					;Return PI data to PC
	MOV	DPTR, #string_spi_return
	CALL	FUNC_UART_SEND_STRING
	MOV	A, R7
	CALL	FUNC_UART_SEND_HEXCHAR
	
	MOV	SBUF, #13
	JMP	$
	MOV	SBUF, #10
	JMP	$
	
	JMP	IDEL
	
IDEL_STRING_TABLE:
	string_system_ready:	DB	13,10,"PC> ",0
	string_spi_send:	DB	13,10,"Send data: 0x",0
	string_spi_return:	DB	13,10,"SPI return: 0x",0

; INTERRUPT SUBROUTINE ---------------------------------

INT_0:
	RETI

TIMER_0:
	CLR	TF0
	
	POP	B					;Return address + 2
	POP	ACC
	ADD	A, #0x02				;Length of JMP$ = 2
	PUSH	ACC
	MOV	A, B
	ADDC	A, #0x00
	PUSH	ACC
	
	RETI

INT_1:
	RETI

TIMER_1:
	CLR	TF1
	RETI

UART:
	JMP	FUNC_UART_INT				;Go to the handler

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; INTERNAL FUNCTIONS -----------------------------------


; EXTERNAL FUNCTIONS -----------------------------------

$INCLUDE(func_spi.a51)
$INCLUDE(func_uart.a51)


; CONSTANT DATA TABLES ---------------------------------



END;
