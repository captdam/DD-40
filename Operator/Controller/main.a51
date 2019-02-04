; Operator console

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
	
;App RAM
	FB_VALVE	EQU	0x20			;Bit addressable
	LR_VALVE	EQU	0x21
	UD_VALVE	EQU	0x22
	LED		EQU	0x23
	C_OUT		EQU	0x24
	
	ENGINE_POWER	EQU	0x30			;Non bit-addressable read/write data
	PRESSURE_DEST	EQU	0x33
	PITCH_DEST	EQU	0x3D
	COMPASS_DEST	EQU	0x47
	C_PWM		EQU	0x4D
	
	PRESSURE_REAL	EQU	0x31			;Non bit-addressable read only data
	PITCH_REAL	EQU	0x3B
	COMPASS_REAL	EQU	0x45
	TEMPERATURE	EQU	0x49
	BAT_VOLTAGE	EQU	0x4B
	
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
		
	MOV	SCON, #0x50				;UART mode1 (8-bit, flex baud), enable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 to 16-bit normal
	SETB	TR1					;Enable timer1 running
	SETB	ET0					;Enable timer0 interrupt
	
	SETB	EA

MAIN:							;Wait for command
	
	JNB	RI, $					;Wait until RX (request from PC)
	CLR	RI
	
	MOV	P1, #0xFF
	
	MOV	P2, #0x7F				;Scan row 7
	NOP
	MOV	SBUF, P1
	JNB	TI, $
	CLR	TI
	
	MOV	P2, #0xBF				;Scan row 6
	NOP
	NOP
	MOV	SBUF, P1
	JNB	TI, $
	CLR	TI
	
	
	
	JMP	MAIN
	
	

; INTERRUPT SUBROUTINE ---------------------------------

INT_0:
	RETI

TIMER_0:
	CLR	TF0
	RETI

INT_1:
	RETI

TIMER_1:
	CLR	TF1
	RETI

UART:
	RETI

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; INTERNAL FUNCTIONS -----------------------------------


; EXTERNAL FUNCTIONS -----------------------------------


; CONSTANT DATA TABLES ---------------------------------



END;
