; Operator console

;SFR - STC89C52RC
	AUXR1		DATA	0xA2
	XICON		DATA	0xC0
	T2CON		DATA	0xC8
	T2MOD		DATA	0xC9
	RCAP2L		DATA	0xCA
	RCAP2H		DATA	0xCB
	TL2		DATA	0xCC
	TH2		DATA	0xCD
	WDT_CONTR	DATA	0xE1
	ISP_DATA	DATA	0xE2
	ISP_ADDRH	DATA	0xE3
	ISP_ADDRL	DATA	0xE4
	ISP_CMD		DATA	0xE5
	ISP_TRIG	DATA	0xE6
	ISP_CONTR	DATA	0xE7
	P4		DATA	0xE8
	
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
	
	RX_PACK_SIZE	EQU	23
	TX_PACK_SIZE	EQU	13
	
;App RAM (SFR)
	FB_VALVE	DATA	0x20			;Bit addressable
	LR_VALVE	DATA	0x21
	UD_VALVE	DATA	0x22
	LED		DATA	0x23
	C_OUT		DATA	0x24
	
	ENGINE_POWER	DATA	0x30			;Non bit-addressable read/write data
	PRESSURE_DEST	DATA	0x33
	PITCH_DEST	DATA	0x3D
	COMPASS_DEST	DATA	0x47
	C_PWM		DATA	0x4D
	
	PRESSURE_REAL	DATA	0x31			;Non bit-addressable read only data
	PITCH_REAL	DATA	0x3B
	COMPASS_REAL	DATA	0x45
	TEMPERATURE	DATA	0x49
	BAT_VOLTAGE	DATA	0x4B

;App RAM (Constant)
	

;App XRAM (UART buffer) address are same on the ROV side					;TODO: Do I really need this much feedback data?
	TX_BUFFER_BEGIN	EQU	0x0000
	TX_BUFFER_END	EQU	TX_BUFFER_BEGIN + TX_PACK_SIZE + 1 ;Not included
	;	FB_VALVE	LR_VALVE	UD_VALVE	LED		C_OUT
	;	ENGINE_POWER	PRESSURE_DEST_L	PRESSURE_DEST_H	PITCH_DEST_L	PITCH_DEST_H
	;	COMPASS_DEST_L	COMPASS_DEST_H	C_PWM		(checksum)
	RX_BUFFER_BEGIN	EQU	0x0080
	RX_BUFFER_END	EQU	RX_BUFFER_BEGIN + RX_PACK_SIZE + 1 ;Not included
	;	FB_VALVE	LR_VALVE	UD_VALVE	LED		C_OUT
	;	ENGINE_POWER	PRESSURE_REAL_L	PRESSURE_REAL_H PRESSURE_DEST_L	PRESSURE_DEST_H
	;	PITCH_REAL_L	PITCH_REAL_H	PITCH_DEST_L	PITCH_DEST_H	COMPASS_REAL_L
	;	COMPASS_REAL_H	COMPASS_DEST_L	COMPASS_DEST_H	TEMPERATURE_L	TEMPERATURE_H
	;	BAT_VLOTAGE_L	BAT_VLOTAGE_H	C_PWM		(checksum)
	
;App pins
	
	
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
	USING	0					;USING REGISTER BANK 0 ALWAYS!!!
	MOV	SP, #0x7F
		
	MOV	SCON, #0x50				;UART mode1 (8-bit, flex baud), enable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 to 16-bit normal 
	SETB	TR1					;Enable timer1 and timer0 running
	SETB	TR0
	
	SETB	EA

MAIN:
	;Scan user input
	
CHECKSUM:
	JNB	F0, $					;Wait for package fully received
	CLR	F0
	
	CLR	A					;Clear A, R0, and R1
	MOV	R0, A
	MOV	R1, A
	
	MOV	AUXR1, #0x01				;Go through all data in the rx buffer
	MOV	DPTR, #RX_BUFFER_BEGIN
	checksum_loop:
	MOVX	A, @DPTR				;Accumulately add to get checksum
	MOV	R1, A					;R1 <-- Last word (there is no DEC DPTR, so using R1 to save the last word, which is the given chacksum)
	ADD	A, R0					;R0 <-- Accumulate result
	MOV	R0, A
	INC	DPTR					;Pointer inc
	MOV	A, DPL					;Track pointer
	CJNE	A, #LOW(TX_BUFFER_END), checksum_loop
	
	MOV	A, R0					;A <-- Data + checksum
	SUBB	A, R1					;Data + checksum - checksum - checksum should be 0
	SUBB	A, R1
	JNZ	$					;Checksum error, stall here

UPDATEUI:
	
	
	
;	MOV	P1, #0xFF
;	
;	MOV	P2, #0x7F				;Scan row 7
;	NOP
;	MOV	SBUF, P1
;	JNB	TI, $
;	CLR	TI
;	
;	MOV	P2, #0xBF				;Scan row 6
;	NOP
;	NOP
;	MOV	SBUF, P1
;	JNB	TI, $
;	CLR	TI
	
	
	
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
	PUSH	AUXR1
	PUSH	ACC
	PUSH	PSW
	JB	RI, UART_RXC				;Check interrupt reason
	
UART_TXC:
	MOV	AUXR1, #0x00				;Using DPTR0, pointed to tx buffer
	
	MOV	A, DPL					;If all data send, exit
	CJNE	A, #LOW(TX_BUFFER_END), uart_txc_send
	JMP	uart_end
	
	uart_txc_send:
	MOVX	A, @DPTR				;Get data from buffer and send to UART
	MOV	SBUF, A
	INC	DPTR					;Pointer inc
	
UART_RXC:
	MOV	AUXR1, #0x01				;Using DPTR1, pointed to rx buffer
	MOV	A, SBUF					;Get data from UART
	
	MOV	TL0, #0x00				;Reset timer0
	MOV	TH0, #0x00
	
	JNB	TF0, uart_rxc_data			;Check sync signal (first word in package (which means there is timer overflow (it has
	JNZ	uart_rxc_data				;been a while sine last word of last package)), the value of the sync signal is 0x00)
	
	uart_rxc_sync:
	CLR	TF0					;Reset the timer overflow flag, reset DPTR to buffer head
	MOV	DPTR, #RX_BUFFER_BEGIN
	
	MOV	A, SP					;Write return PC to MAIN
	SUBB	A, #5
	XCH	A, R0					;Saving R0 and make R0 pointes to return address
	MOV	@R0, #LOW(MAIN)
	INC	R0
	MOV	@R0, #HIGH(MAIN)
	XCH	A, R0					;Restore R7
	
	JMP	uart_end				;Exit
	
	uart_rxc_data:
	CLR	TF0					;Reset the timer overflow flag
	MOVX	@DPTR, A				;Save the word in buffer
	INC	DPTR					;Pointer inc
	
	MOV	A, DPL					;If all data received, set flag
	CJNE	A, #LOW(TX_BUFFER_END), uart_end
	SETB	F0
	
	uart_end:
	POP	PSW
	POP	ACC
	POP	AUXR1
	RETI

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; INTERNAL FUNCTIONS -----------------------------------


; EXTERNAL FUNCTIONS -----------------------------------


; CONSTANT DATA TABLES ---------------------------------



END;
