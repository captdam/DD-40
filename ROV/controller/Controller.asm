; Chip config
.EQU	RC_CLOCK_CALIBRATE	=	0x3D
.EQU	FOSC			=	8000000

; App config
#define	SYSCLK_SCALE		(8)
#define	BAUD			(2400)

#if SYSCLK_SCALE == 1
	.EQU	SYSCLK_SCALER	=	0x00
#elif SYSCLK_SCALE == 2
	.EQU	SYSCLK_SCALER	=	0x01
#elif SYSCLK_SCALE == 4
	.EQU	SYSCLK_SCALER	=	0x02
#elif SYSCLK_SCALE == 8
	.EQU	SYSCLK_SCALER	=	0x03
#elif SYSCLK_SCALE == 16
	.EQU	SYSCLK_SCALER	=	0x04
#elif SYSCLK_SCALE == 32
	.EQU	SYSCLK_SCALER	=	0x05
#elif SYSCLK_SCALE == 64
	.EQU	SYSCLK_SCALER	=	0x06
#elif SYSCLK_SCALE == 128
	.EQU	SYSCLK_SCALER	=	0x07
#elif SYSCLK_SCALE == 256
	.EQU	SYSCLK_SCALER	=	0x08
#else
	#error "Time scale not support, using 1, 2, 4, 8, 16, 32, 64, 128 or 256."
#endif

.EQU	USART_SCALE		=	FOSC/SYSCLK_SCALE/16/BAUD-1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                   DATA  SEG                   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Notice: all multi-byte variables are little endian
; eg: If XX(0x48, 2-byte) = 0x1234
;     then, @0x49 = 0x34, @0x48 = 0x12
.DSEG

.ORG	0x0100					;App SFR tables (0x0100 - 0x017F), see image in /Communication for description
	.org 0x0120
	FB_VALVE:	.BYTE	1
	LR_VALVE:	.BYTE	1
	UD_VALVE:	.BYTE	1
	LED:		.BYTE	1
	C_OUT:		.BYTE	1
	.org 0x0130
	ENGINE_POWER:	.BYTE	1
	PRESSURE_REAL:	.BYTE	2
	PRESSURE_DEST:	.BYTE	2
	ACCEL_X:	.BYTE	2
	ACCEL_Y:	.BYTE	2
	ACCEL_Z:	.BYTE	2
	PITCH_REAL:	.BYTE	2
	PITCH_DEST:	.BYTE	2
	MAG_X:		.BYTE	2
	MAG_Y:		.BYTE	2
	MAG_Z:		.BYTE	2
	COMPASS_REAL:	.BYTE	2
	COMPASS_DEST:	.BYTE	2
	TEMPERATURE:	.BYTE	2
	BAT_VOLTAGE:	.BYTE	2
	C_PWM:		.BYTE	1

.ORG	0x0180					;Static intermedia variables
	PHASE:		.BYTE	1

.ORG	0x0200					;Tx/Rx buffer
	.org 0x0200
	.EQU	RX_BUFFER_SIZE	=	0x80 - 2
	RX_BUFFER:	.BYTE	RX_BUFFER_SIZE
	RX_POINTER:	.BYTE	2		;Pointer, points to the next valve
	.EQU	RX_PACKAGE_SIZE	=	12	;See the image in /Communication for package structure
	.org 0x0280				;The buffer size is way larger than it needs, in case of buffer overflow
	.EQU	TX_BUFFER_SIZE	=	0x80 - 2
	TX_BUFFER:	.BYTE	TX_BUFFER_SIZE
	TX_POINTER:	.BYTE	2
	.EQU	TX_PACKAGE_SIZE	=	10

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;                   CODE  SEG                   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.CSEG

; Interrupt vector
.ORG	0x0000	JMP	VEC_RESET
.ORG	0x0002	JMP	VEC_EXT_INT0
.ORG	0x0004	JMP	VEC_EXT_INT1
.ORG	0x0006	JMP	VEC_PCINT0
.ORG	0x0008	JMP	VEC_PCINT1
.ORG	0x000A	JMP	VEC_PCINT2
.ORG	0x000C	JMP	VEC_WDT
.ORG	0x000E	JMP	VEC_TIM2_COMPA
.ORG	0x0010	JMP	VEC_TIM2_COMPB
.ORG	0x0012	JMP	VEC_TIM2_OVF
.ORG	0x0014	JMP	VEC_TIM2_CAPT
.ORG	0x0016	JMP	VEC_TIM1_COMPA
.ORG	0x0018	JMP	VEC_TIM1_COMPB
.ORG	0x001A	JMP	VEC_TIM1_OVF
.ORG	0x001C	JMP	VEC_TIM0_COMPA
.ORG	0x001E	JMP	VEC_TIM0_COMPB
.ORG	0x0020	JMP	VEC_TIM0_OVF
.ORG	0x0022	JMP	VEC_SPI_STC
.ORG	0x0024	JMP	VEC_USART_RXC
.ORG	0x0026	JMP	VEC_USART_UDRE
.ORG	0x0028	JMP	VEC_USART_TXC
.ORG	0x002A	JMP	VEC_ADC
.ORG	0x002C	JMP	VEC_EE_RDY
.ORG	0x002E	JMP	VEC_ANA_COMP
.ORG	0x0030	JMP	VEC_TWI
.ORG	0x0032	JMP	VEC_SPM_RDY


; App program ----------------------------------------------

; Config MCU
VEC_RESET:
INI:
	;Setup SP
	LDI	R17, HIGH(RAMEND)
	LDI	R16, LOW(RAMEND)
	OUT	SPH, R17
	OUT	SPL, R16
	
	;Setup Tx/Rx buffer pointer
	LDI	R17, HIGH(RX_BUFFER)		;Get address of the buffer
	LDI	R16, LOW(RX_BUFFER)
	STS	RX_POINTER+1, R17		;Set pointer's value to the beginning of the buffer
	STS	RX_POINTER, R16
	
	LDI	R17, HIGH(TX_BUFFER)
	LDI	R16, LOW(TX_BUFFER)
	STS	TX_POINTER+1, R17
	STS	TX_POINTER, R16

	;Setup interrupt mode
;	LDI	R16, 0x02
;	OUT	MCUCR, R16
;	LDI	R16, 0x01
;	OUT	MCUCR, R16

	;Calibrate clock and set pre-scaler
	LDI	R16, RC_CLOCK_CALIBRATE
	STS	OSCCAL, R16

	LDI	R16, 0x80
	STS	CLKPR, R16
	LDI	R16, SYSCLK_SCALER
	STS	CLKPR, R16

	;Setup pin direction
	LDI	R16, 0b11111100			;PD =	Out7	Out6	Out5	Out4	Out3	Out2	Tx	Rx
	OUT	DDRD, R16
	LDI	R16, 0b11111100
	OUT	PORTD, R16

	LDI	R16, 0b00000000			;PC =	X	RESET	SCL	SDA	Pres	B_Vol	In1	In0
	OUT	DDRC, R16
	LDI	R16, 0b00000000
	OUT	PORTC, R16

	LDI	R16, 0b11101111			;PB =	Out1	Out0	SCK	SPI-SDI	SPI-SDO	PWM	C_PWM	/AUX
	OUT	DDRB, R16
	LDI	R16, 0b00000001
	OUT	PORTB, R16

	;Setup USART communication with operator-side controller
	LDI	R16, HIGH(USART_SCALE)
	STS	UBRR0H, R16
	LDI	R16, LOW(USART_SCALE)
	STS	UBRR0L, R16
	LDI	R16, 0b11011000			;Enable Tx/Rx and Rx/Tx interrupt, 8 bits data
	STS	UCSR0B, R16
	LDI	R16, 0b00000110			;Async USART (UART), no parity, 1 stop bit, 8 bits data
	STS	UCSR0C, R16

	;Setup SPI
	LDI	R16, 0b01010011			;No interrupt, SPI enable, MSB first, as masrter, mode0, 1/128 speed
	OUT	SPCR, R16

;;;	;Ini app SFR (FOR TEST)
	.MACRO	INIDATA_MACRO
	LDI	R16, @0
	STS	@1, R16
	.ENDMACRO

	INIDATA_MACRO	0x30, FB_VALVE
	INIDATA_MACRO	0x31, LR_VALVE
	INIDATA_MACRO	0x32, UD_VALVE
	INIDATA_MACRO	0x33, LED
	INIDATA_MACRO	0x34, C_OUT
	INIDATA_MACRO	0x35, ENGINE_POWER
	INIDATA_MACRO	0x36, PRESSURE_REAL
	INIDATA_MACRO	0x37, PRESSURE_REAL+1
	INIDATA_MACRO	0x38, PRESSURE_DEST
	INIDATA_MACRO	0x39, PRESSURE_DEST+1
	INIDATA_MACRO	0x41, PITCH_REAL
	INIDATA_MACRO	0x42, PITCH_REAL+1
	INIDATA_MACRO	0x43, PITCH_DEST
	INIDATA_MACRO	0x44, PITCH_DEST+1
	INIDATA_MACRO	0x45, COMPASS_REAL
	INIDATA_MACRO	0x46, COMPASS_REAL+1
	INIDATA_MACRO	0x47, COMPASS_DEST
	INIDATA_MACRO	0x48, COMPASS_DEST+1
	INIDATA_MACRO	0x49, TEMPERATURE
	INIDATA_MACRO	0x4A, TEMPERATURE+1
	INIDATA_MACRO	0x4B, BAT_VOLTAGE
	INIDATA_MACRO	13, BAT_VOLTAGE+1
	INIDATA_MACRO	10, C_PWM

	;Setup ROV phase timer
	LDI	R16, 8
	STS	PHASE, R16
	LDI	R16, 0b00000101			;Timer2 scale set to 1024
	STS	TCCR2B, R16
	LDI	R16, 0b00000001			;Enable timer2 overflow interrupt
	STS	TIMSK2, R16

	SEI					;Ini done, enable interrupt

; Cycle. Compare VALUE_DEST with VALUE_REAL to autopilot the ROV
MAIN:	
	
	JMP	MAIN

VEC_TIM2_OVF:
	;This timer overflow interrupt is the main cycle of the ROV
	SEI
	
	;Reset timer
	LDI	R16, 0xFF - 244			;1024 * 244 / 8MHz ~= 250k/8M = 1/32 (32 triggers pre 1s, 8 triggers pre 1/4s)
	STS	TCNT2, R16
	SBI	PINB, 2

	;Changing phase
	LDS	R16, PHASE
	INC	R16
	STS	PHASE, R16

	;Call phase function
	ANDI	R16, 0b00000111			;There is 8 phases (0~7)
	BREQ	phase_datatransfer		;Phase 0:	datatransfer
	SBRC	R16, 0				;Phase 2,4,6:	apply (skip next line)
	JMP	phase_scan			;Otherwise:	scan
	
	phase_apply:
	CALL	APPLY
	JMP	phase_end

	phase_scan:
	CALL	SCAN
	JMP	phase_end

	phase_datatransfer:
	CALL	DATATRANSFER
	JMP	phase_end

	phase_end:
	RETI

	
; Receive command byte from controller
VEC_USART_RXC:
	PUSH	R27
	PUSH	R26
	PUSH	R16
	LDS	R16, SREG
	PUSH	R16
	SEI

	LDS	R27, RX_POINTER+1		;Get the buffer pointer in RX
	LDS	R26, RX_POINTER

	LDS	R16, UDR0			;Move data from USART port to the buffer
	ST	X+, R16

	STS	RX_POINTER+1, R27		;Update pointer
	STS	RX_POINTER, R26

	POP	R16
	STS	SREG, R16
	POP	R16
	POP	R26
	POP	R27
	RETI

	
; Send data byte to controller
VEC_USART_TXC:
	PUSH	R27
	PUSH	R26
	PUSH	R16
	LDS	R16, SREG
	PUSH	R16
	SEI

	LDS	R27, TX_POINTER+1		;Get the buffer pointer in TX
	LDS	R26, TX_POINTER

	LDI	R16, LOW(TX_BUFFER)+TX_PACKAGE_SIZE+1
	CP	R16, R26
	BREQ	vec_usart_udre_end		;Pointer reaches end of query

	LD	R16, X+				;Move data from buffer to the UASRT port
	STS	UDR0, R16

	STS	TX_POINTER+1, R27		;Update pointer
	STS	TX_POINTER, R26

	vec_usart_udre_end:
	POP	R16
	STS	SREG, R16
	POP	R16
	POP	R26
	POP	R27
	RETI


; Unused vector ----------------------------------------------

;VEC_RESET:
VEC_EXT_INT0:
VEC_EXT_INT1:
VEC_PCINT0:
VEC_PCINT1:
VEC_PCINT2:
VEC_WDT:
VEC_TIM2_COMPA:
VEC_TIM2_COMPB:
;VEC_TIM2_OVF:
VEC_TIM2_CAPT:
VEC_TIM1_COMPA:
VEC_TIM1_COMPB:
VEC_TIM1_OVF:
VEC_TIM0_COMPA:
VEC_TIM0_COMPB:
VEC_TIM0_OVF:
VEC_SPI_STC:
;VEC_USART_RXC:
VEC_USART_UDRE:
;VEC_USART_TXC:
VEC_ADC:
VEC_EE_RDY:
VEC_ANA_COMP:
VEC_TWI:
VEC_SPM_RDY:
	JMP	VEC_RESET

; Subroutines ----------------------------------------------


; Phase user input, update app SFR, scan app SFR, send data to user
DATATRANSFER:
	; This subroutine is triggered by timer every 1/4s
	; 1.Check received package
	; 2.If coming package is OK, update app SFR
	; 3.Scan app SFR and send to controller
	PUSH	R27
	PUSH	R26
	PUSH	R18
	PUSH	R17
	PUSH	R16
	LDS	R16, SREG
	PUSH	R16

	;Check RX data
	LDI	R27, HIGH(RX_BUFFER)		;Get address of the beginning of the buffer in RX
	LDI	R26, LOW(RX_BUFFER)
	STS	RX_POINTER+1, R27		;Reset pointer's value to the beginning of the buffer
	STS	RX_POINTER, R26

	LDI	R18, RX_PACKAGE_SIZE		;Get package length in R18
	CLR	R16				;Prepare to calculate checksum
	datatransfer_rx_checksum_loop:
	LD	R17, X+
	ADD	R16, R17
	DEC	R18
	BRNE	datatransfer_rx_checksum_loop	;Loop through all data

	LD	R17, X				;Checksum from operator
	CPSE	R17, R16			;Compare operator's chacksum and calculated checksum, if equal (checksum OK), update app SFR
	JMP	datatransfer_send		;Otherwise, ignor this package

	;Update app SFR
	datatransfer_rx_update:
	LDI	R27, HIGH(RX_BUFFER)		;Get address of the beginning of the buffer in RX
	LDI	R26, LOW(RX_BUFFER)
	
	LD	R16, X				;The first word is mixed of FB_VALVE and LED SFR
	ANDI	R16, 0x0F
	STS	FB_VALVE, R16
	
	LD	R16, X+
	ANDI	R16, 0xF0
	STS	LED, R16
	
	.MACRO	DATATRANSFER_RXMACRO		;Move data from buffer to app's SFR
	LD	R16, X+
	STS	@0, R16
	.ENDMACRO
	
	DATATRANSFER_RXMACRO	LR_VALVE
	DATATRANSFER_RXMACRO	UD_VALVE
	DATATRANSFER_RXMACRO	C_OUT
	DATATRANSFER_RXMACRO	ENGINE_POWER
	DATATRANSFER_RXMACRO	PRESSURE_DEST
	DATATRANSFER_RXMACRO	PRESSURE_DEST+1
	DATATRANSFER_RXMACRO	PITCH_DEST
	DATATRANSFER_RXMACRO	PITCH_DEST+1
	DATATRANSFER_RXMACRO	COMPASS_DEST
	DATATRANSFER_RXMACRO	COMPASS_DEST+1
	DATATRANSFER_RXMACRO	C_PWM
	
	
	;Scan app SFR and send
	datatransfer_send:
	LDI	R27, HIGH(TX_BUFFER)		;Get address of the beginning of the buffer in RX
	LDI	R26, LOW(TX_BUFFER)
	STS	TX_POINTER+1, R27		;Reset pointer's value to the beginning of the buffer
	STS	TX_POINTER, R26

	LDI	R16, TX_PACKAGE_SIZE		;First byte: package data length
	ST	X+, R16

	CLR	R18				;Claculate checksum
	
	.MACRO	DATATRANSFER_TXMACRO		;Move date from SFR's values to buffer
	LDS	R16, @0
	ADD	R18, R16
	ST	X+, R16
	.ENDMACRO
	
	DATATRANSFER_TXMACRO	PRESSURE_REAL
	DATATRANSFER_TXMACRO	PRESSURE_REAL+1
	DATATRANSFER_TXMACRO	PITCH_REAL
	DATATRANSFER_TXMACRO	PITCH_REAL+1
	DATATRANSFER_TXMACRO	COMPASS_REAL
	DATATRANSFER_TXMACRO	COMPASS_REAL+1
	DATATRANSFER_TXMACRO	TEMPERATURE
	DATATRANSFER_TXMACRO	TEMPERATURE+1
	DATATRANSFER_TXMACRO	BAT_VOLTAGE
	DATATRANSFER_TXMACRO	BAT_VOLTAGE+1

	ST	X, R18				;Last byte: checksum
	
	LDI	R16, 0xFF			;Send synch signal, and begin to send package
	STS	UDR0, R16
	
	POP	R16
	STS	SREG, R16
	POP	R16
	POP	R17
	POP	R18
	POP	R26
	POP	R27
	RET

; Scan data from sensors
SCAN:
	
	RET

; Compare seneor data and apply actuator
APPLY:
	;PHSH

	;
	RET

; Lookup table
BAT_VOLTAGE_TABLE:
	; ADC read (1/3 scale, 15V max real, 5V max read, 7-bit resulution)
	; ADC-0x00 = 0.0V, ADC-0x02 = 0.1V, ADC-0x04 = 0.2V, ADC-0x06 = 0.4V, 0xFE = 15V
	; Data output to operator (BCD10 + BCD1 + BCD0.1 + 0)
	DW	0x0000, 0x0010, 0x0020, 0x0040, 0x0050, 0x0060, 0x0070, 0x0080,
		0x0090, 0x0110, 0x0120, 0x0130, 0x0140, 0x0150, 0x0170, 0x0180,
		0x0190, 0x0200, 0x0210, 0x0220, 0x0240, 0x0250, 0x0260, 0x0270,
		0x0280, 0x0300, 0x0310, 0x0320, 0x0330, 0x0340, 0x0350, 0x0370,
		0x0380, 0x0390, 0x0400, 0x0410, 0x0430, 0x0440, 0x0450, 0x0460,
		0x0470, 0x0480, 0x0500, 0x0510, 0x0520, 0x0530, 0x0540, 0x0560,
		0x0570, 0x0580, 0x0590, 0x0600, 0x0610, 0x0630, 0x0640, 0x0650,
		0x0660, 0x0670, 0x0690, 0x0700, 0x0710, 0x0720, 0x0730, 0x0740,
		0x0760, 0x0770, 0x0780, 0x0790,	0x0800, 0x0810, 0x0830, 0x0840,
		0x0850, 0x0860, 0x0870, 0x0890, 0x0900, 0x0910, 0x0920, 0x0930,
		0x0940, 0x0960, 0x0970, 0x0980, 0x0990, 0x1000, 0x1010, 0x1030,
		0x1040, 0x1050, 0x1060, 0x1070, 0x1090, 0x1100, 0x1110, 0x1120,
		0x1130, 0x1150, 0x1160, 0x1170, 0x1180, 0x1190, 0x1200, 0x1220,
		0x1230, 0x1240, 0x1250, 0x1260, 0x1280, 0x1290, 0x1300, 0x1310,
		0x1320, 0x1330, 0x1350, 0x1360, 0x1370, 0x1380, 0x1390, 0x1410,
		0x1420, 0x1430, 0x1440, 0x1450, 0x1460, 0x1480, 0x1490, 0x1500
PRESSURE_TABLE:
	