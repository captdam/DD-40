; Operator console

; CONFIG FILES -----------------------------------
$INCLUDE	(c_sfr.a51)
$INCLUDE	(c_cfg.a51)
$INCLUDE	(c_ram.a51)
	
; NOTICE:	MAIN ROUTINE			USING REGISTER BANK 0 ONLY!
;		LCD INTERRUPT SERVICE ROUTINE	USING REGISTER BANK 2 ONLY!
;		UART INTERRUPT SERVICE ROUTINE	USING REGISTER BANK 3 ONLY!
; NOTICE: LCD MODULE IS WRITE-ONLY!


; INTERRUPT VECTOR MAP -----------------------------------
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


; EXTERNAL FUNCTIONS -----------------------------------

$INCLUDE	(f_delay.a51)
$INCLUDE	(f_lcd.a51)

; INTERNAL FUNCTIONS -----------------------------------

USING	0
DIGITAL_INPUT:						;User enter a digital to AutoPilot console
	; Input: R7(ToBeAppend)
	; Output: None - Directly write to RAM
	; Modify: DIGI_BUFFER_X
	MOV	DIGI_BUFFER_E, DIGI_BUFFER_H		;Data shift left, Data Low = input
	MOV	DIGI_BUFFER_H, DIGI_BUFFER_L
	MOV	DIGI_BUFFER_L, R7			;Input is guaranted to be in the range of 0x00-0x09
	RET

DIGITAL_GETPWM:
	; Input: None - Directly fetch from RAM
	; Output: A(PWM%InBCD,0xA0For100%)
	; Modify: A
	MOV	A, DIGI_BUFFER_E
	JZ	DIGITAL_GETPWM_read			;If buffer_EXH has value (100s is not 0), set PWM to 100
	MOV	A, #0xA0
	RET
	DIGITAL_GETPWM_read:
	MOV	A, DIGI_BUFFER_H			;Get 10s to higher nibble
	SWAP	A
	ORL	A, DIGI_BUFFER_L			;Add 1s to lower nibble
	RET
	
; MAIN CODE --------------------------------------------

USING	0
INI:							;Boot setup
	MOV	SP, #0x7F
	
	CLR	LCD_RW					;Set LCD to Write mode
	__M_LCD_PREPARE					;LCD ini
	
	MOV	DPTR, #LCDTEMPLATE			;Write LCD data to buffer
	MOV	R0, #LCD_BUFFER
	INI_lcd:
	CLR	A
	MOVC	A, @A+DPTR				;Copy from code segment
	MOVX	@R0, A					;Write to XRAM
	INC	DPTR
	INC	R0
	CJNE	R0, #0x40+LCD_BUFFER, INI_lcd
	
	MOV	SCON, #0x50				;UART mode1 (8-bit, flex baud), enable read
	SETB	ES
	
	MOV	TH1, #0xF3				;Set timer1 auto-reload value: -1M/2400/32
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 mode to 16-bit timer - timer1 UART BAUD generator, timer2 is LCD refresh rate generator
	SETB	TR1					;Enable timer1 and timer0, enable timer0 interrupt
	SETB	TR0
	SETB	ET0
	
	MOV	RCAP2H, #0x10				;UART BAUD generator = 13 - Timer2 is for Rx timeout, which identify new package
	MOV	RCAP2L, #0x40				;To send 1 byte = 13 * 32 * 10 (1 start bit + 8 data bits + 1 stop bit), takes 4.16ms
	MOV	T2MOD, #0x01				;Time2 count down
	SETB	TR2					;Enable timer2 and its interrupt
	SETB	ET2
	
	MOV	AR_20, #LCD_BUFFER			;Reset LCD buffer pointer, both LCDs share same pointer
	MOV	AR_30, #TX_BUFFER			;Reset Tx/Rx buffer pointer (flush buffers)
	MOV	AR_31, #RX_BUFFER
	
	MOV	SCAN_DIVIDER, #0x00			;Slow down keyboard (digital input) scan speed
	
	SETB	EA

USING	0
WAIT:
	JMP	$
	
USING	0
MAIN:							;Main cycle: execute while receive synch signal
	CLR	LED_IDEL
	CLR	LED_COMERROR
	
	MOV	AR_30, #TX_BUFFER			;Reset Tx/Rx buffer pointer (flush buffers)
	MOV	AR_31, #RX_BUFFER
	
USING	0
SCAN:							;Scan keyboard
	MOV	KEY_DRIVE, #01111111B			;Scan row 7: X - X - X - X - X - XForward - Forward - Backward
	NOP
	MOV	A, KEY_SCAN
	CPL	A					;All keys are active low
	ANL	A, #00000111B
	MOV	FB_VALVE, A
	
	MOV	KEY_DRIVE, #10111111B			;Scan row 6: ShiftLeft - ShiftRight - ShiftUp - ShiftDown - TurnLeft - TurnRight - PitchUp - PitchDown
	NOP
	MOV	A, KEY_SCAN
	CPL	A
	MOV	DIR_VALVE, A
	
	MOV	KEY_DRIVE, #11011111B			;Scan row 5: AP - AP - AP - NaviLight - MainLight - X - X - X
	NOP
	MOV	A, KEY_SCAN
	CPL	A
	ANL	A, #11111000B
	MOV	FUNC, A
	
	MOV	KEY_DRIVE, #11101111B			;Scan row 4: Custom output
	NOP
	MOV	A, KEY_SCAN
	CPL	A
	MOV	C_OUT, A
	
	MOV	A, SCAN_DIVIDER				;Clock divider for digital input
	ADD	A, #(0x100 / 4)
	MOV	SCAN_DIVIDER, A
	JC	SCAN_digital
	JMP	SCAN_end
	
	SCAN_digital:
	MOV	KEY_DRIVE, #11110111B			;Scan row 3: Digital input low
	MOV	A, KEY_SCAN
	MOV	R7, #8
	scan_3_loop:					;Scan all 8 keys on row 2
	RLC	A					;Rotate to right, first bit is key_8
	JC	scan_3_keyreleased			;key press = 0, key released = 1
	CALL	DIGITAL_INPUT
	JMP	SCAN_end				
	scan_3_keyreleased:
	DJNZ	R7, scan_3_loop				;R7 reaches 0 (8 to 1 has been scaned)
	
	MOV	KEY_DRIVE, #11111011B			;Scan row 2: Digital input high
	NOP
	
	scan_2_compass:					;User apply value from gitital input buffer to AutoPilot compass control, check required
	JB	KEY_SCAN.7, scan_2_pressure
	MOV	A, DIGI_BUFFER_L			;Apply COMPASS_DEST low, assume it is correct
	SWAP	A
	MOV	COMPASS_DEST, A
	MOV	A, DIGI_BUFFER_E			;Apply COMPASS_DEST high as well
	SWAP	A
	ORL	A, DIGI_BUFFER_H
	MOV	COMPASS_DEST+1, A
	ADD	A, #-0x36				;Is the number >= 360
	JNC	SCAN_end				;35+(-36):NC; 36+(-36):C
	CLR	A
	MOV	COMPASS_DEST+1, A			;COMPASS >= 360, invalid input! Correct to 00x
	MOV	COMPASS_DEST, A
	JMP	SCAN_end
	
	scan_2_pressure:				;User apply value from gitital input buffer to AutoPilot pressure (depth) control, any depth is OK
	JB	KEY_SCAN.6, scan_2_pitch
	MOV	A, DIGI_BUFFER_E			;Apply PRESSURE_DEST high (xx.00m)
	SWAP	A
	ORL	A, DIGI_BUFFER_H
	MOV	PRESSURE_DEST+1, A
	MOV	A, DIGI_BUFFER_L			;Apply PRESSURE_DEST high (00.xxm), leave 0.01s to be 0 (resolution 0.1m)
	SWAP	A
	MOV	PRESSURE_DEST, A
	JMP	SCAN_end
	
	scan_2_pitch:					;User apply value from gitital input buffer to AutoPilot pitch control, check required
	JB	KEY_SCAN.5, scan_2_cpwm
	MOV	A, DIGI_BUFFER_L			;Apply PITCH_DEST low, assume it is correct
	SWAP	A
	MOV	PITCH_DEST, A
	MOV	A, DIGI_BUFFER_E			;Apply PITCH_DEST high as well
	SWAP	A
	ORL	A, DIGI_BUFFER_H
	MOV	PITCH_DEST+1, A
	;Valid range: 0x00-0x09, 0x27-0x29, 0x30-0x35. Using math method will be too complex; hence, using lookup table
	MOV	DPTR, #PITCH_VALIDVALUE
	MOVC	A, @A+DPTR				;DPTR = base value, A is the user input
	JNZ	SCAN_end				;Result != 0, valid; otherwise, set to 0
	CLR	A
	MOV	PITCH_DEST+1, A
	MOV	PITCH_DEST, A
	JMP	SCAN_end
	
	scan_2_cpwm:					;User apply value from gitital input buffer to custom PWM output control
	JB	KEY_SCAN.4, scan_2_engine
	CALL	DIGITAL_GETPWM
	MOV	C_PWM, A
	JMP	SCAN_end
	
	scan_2_engine:					;User apply value from gitital input buffer to engine power control
	JB	KEY_SCAN.3, scan_2_0
	CALL	DIGITAL_GETPWM
	MOV	ENGINE_POWER, A
	JMP	SCAN_end
	
	scan_2_0:					;If this key is 0, it will make the scaning of row2 faster and code will be smaller (so I can use DJNZ)
	JB	KEY_SCAN.1, scan_2_9
	MOV	R7, #0					
	CALL	DIGITAL_INPUT
	JMP	SCAN_end
	scan_2_9:
	JB	KEY_SCAN.0, SCAN_end
	MOV	R7, #9
	CALL	DIGITAL_INPUT
	JMP	SCAN_end
	
	SCAN_end:
	MOV	KEY_DRIVE, #11111111B			;Keyboard scan end
	
	;	;Test
;	MOV	C_PWM, #0x35				;C_PWM = 035%
;	MOV	PITCH_DEST+1, #0x29			;PITCH_DEST = 296 (64 down)
;	MOV	PITCH_DEST, #0x60
;	MOV	COMPASS_DEST+1, #0x13			;COMPASS_DEST = 135
;	MOV	COMPASS_DEST, #0x50
;	MOV	PRESSURE_DEST+1, #0x24			;PRESSURE_DEST = 24.55m
;	MOV	PRESSURE_DEST, #0x55
;	MOV	ENGINE_POWER, #0xA0			;Engine power = 100%
;	MOV	DIGI_BUFFER_E, #0x01			;DIGI_BUFFER = 123
;	MOV	DIGI_BUFFER_H, #0x02
;	MOV	DIGI_BUFFER_L, #0x03
	;End of test
	
USING	0
PACK:							;App SFR --> Tx buffer, and send
	
	MOV	SBUF, FB_VALVE				;Send first word (not nessary to save it in buffer)
	MOV	R2, FB_VALVE				;Checksum
	
	MOV	AR_30, #TX_BUFFER+1			;Buffer pointer set to second word (buffer --> UART)
	MOV	R0, #TX_BUFFER+1			;(App SFR --> buffer) XRAM address < 0x0100, hence R0 is OK
	MOV	R1, #FB_VALVE+1
	
	PACK_loop:
	MOV	A, @R1					;Get data from App SFR
	MOVX	@R0, A					;Save it to Tx buffer
	ADD	A, R2					;Accumulately adding R2
	MOV	R2, A
	INC	R0					;Pointer++
	INC	R1
	CJNE	R1, #TX_CHECKSUM, PACK_loop		;Loop for 14 times (1 already send, 14 not send, 1 checksum (not need), total 16)
	
	CLR	A
	CLR	C
	SUBB	A, R2					;Checksum
	MOVX	@R0, A
	
USING	0
COMMAND_UI:						;Update command data to LCD0 buffer
	MOV	A, PITCH_DEST+1				;PITCH_DEST 100s and 10s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	0,0,0
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, PITCH_DEST				;PITCH_DEST 1s
	CALL	BCDHIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, COMPASS_DEST+1			;COMPASS_DEST 100s and 10s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	0,0,5
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, COMPASS_DEST				;COMPASS_DEST 1s
	CALL	BCDHIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, PRESSURE_DEST+1			;PRESSURE_DEST 10s and 1s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	0,0,10
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, PRESSURE_DEST			;PRESSURE_DEST 0.1s and 0.01s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	0,0,13
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, C_PWM				;C_PWM = 100? 0xA0 (BCD100)
	CJNE	A, #0xA0, COMMAND_UI_pwm
	MOV	A, #'1'					;C_PWM = 100
	__M_LCD_WRITEBUFFER	0,1,1
	MOV	A, #'0'
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	JMP	COMMAND_UI_pwm_end
	
	COMMAND_UI_pwm:
	MOV	A, #'0'					;C_PWM 100s
	__M_LCD_WRITEBUFFER	0,1,1
	MOV	A, C_PWM				;C_PWM 10s and 1s
	CALL	BCD2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, B
	__M_LCD_APPENDBUFFER
	COMMAND_UI_pwm_end:
	
	MOV	A, ENGINE_POWER				;C_PWM = 100? 0xA0 (BCD100)
	CJNE	A, #0xA0, COMMAND_UI_engine
	MOV	A, #'1'					;C_PWM = 100
	__M_LCD_WRITEBUFFER	0,1,7
	MOV	A, #'0'
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	JMP	COMMAND_UI_engine_end
	
	COMMAND_UI_engine:
	MOV	A, #'0'					;C_PWM 100s
	__M_LCD_WRITEBUFFER	0,1,7
	MOV	A, ENGINE_POWER				;C_PWM 10s and 1s
	CALL	BCD2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, B
	__M_LCD_APPENDBUFFER
	COMMAND_UI_engine_end:
	
	MOV	A, DIGI_BUFFER_E			;Digital input EXH (100)
	CALL	BCDLOW2ASCII
	__M_LCD_WRITEBUFFER	0,1,13
	MOV	A, DIGI_BUFFER_H			;Digital input High (10)
	CALL	BCDLOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, DIGI_BUFFER_L			;Digital input Low (1)
	CALL	BCDLOW2ASCII
	__M_LCD_APPENDBUFFER
	
USING	0
WAITPACKAGE:
	SETB	LED_IDEL
	CLR	A					;Rx_Buffer located in 0xF0 - 0xFF, when all data received (16 word: 15 data + 1 checksum), buffer pointer should be 0 (overflow)
	CJNE	A, AR_31, $				;Wait until package fully received (Notice: R31(Rx buffer pointer) is a real-time value)
	CLR	LED_IDEL
	
USING	0
CHECKSUM:
	MOV	R2, #0					;Clear R2, prepare to calculate checksum
	MOV	R0, #RX_BUFFER				;Go through all data in the rx buffer
	
	CHECKSUM_loop:
	MOVX	A, @R0					;Accumulately adding to get checksum
	ADD	A, R2
	MOV	R2, A
	INC	R0					;Pointer++
	CJNE	R0, #0, CHECKSUM_loop			;Rx_Buffer located in 0xF0 - 0xFF, when all data are added, R0 should be 0x100, which will be truncated to 0x00
	
	SETB	LED_COMERROR
	SETB	LED_IDEL
	JNZ	$					;Data + checksum should be 0. If checksum error, stall here
	CLR	LED_COMERROR
	CLR	LED_IDEL

USING	0
UNPACK:							;Rx buffer --> App SFR
	MOV	R0, #RX_BUFFER
	MOV	R1, #PRESSURE_REAL
	
	UNPACK_loop:
	MOVX	A, @R0
	MOV	@R1, A
	INC	R0
	INC	R1 
	CJNE	R1, #RX_CHECKSUM, UNPACK_loop		;Loop for 15 times (15 data, 1 checksum (not need), total 16)

USING	0
DATAUI:							;Update ROV data to LCD1 buffer
	MOV	A, BAT_VOLTAGE+1			;BAT_VOLTAGE 10s and 1s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	1,0,0
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, BAT_VOLTAGE				;BAT_VOLTAGE 0.1s
	CALL	BCDHIGH2ASCII
	__M_LCD_WRITEBUFFER	1,0,3
	
	MOV	A, TEMPERATURE+1			;TEMPERATURE sign (ASCII)
	ANL	A, #0xF0
	SWAP	A
	ORL	A, #0x20
	__M_LCD_WRITEBUFFER	1,0,6
	
	MOV	A, TEMPERATURE+1			;TEMPERATURE 10s
	CALL	BCDLOW2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, TEMPERATURE				;TEMPERATURE 1s and 0.1s
	CALL	BCD2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, B
	__M_LCD_WRITEBUFFER	1,0,10
	
	MOV	A, C_IN					;C_IN 1
	ANL	A, #00000010B
	RR	A
	ORL	A, #0xFE				;If high, print 0xFF (black block); otherwise, print 0xFE (space)
	__M_LCD_WRITEBUFFER	1,0,14
	
	MOV	A, C_IN					;C_IN 0
	ANL	A, #00000001B
	ORL	A, #0xFE
	__M_LCD_APPENDBUFFER
	
	MOV	A, PITCH_REAL+1				;PITCH_REAL 100s and 10s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	1,1,0
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, PITCH_REAL				;PITCH_REAL 1s
	CALL	BCDHIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, COMPASS_REAL+1			;COMPASS_REAL 100s and 10s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	1,1,5
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, COMPASS_REAL				;COMPASS_REAL 1s
	CALL	BCDHIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, PRESSURE_REAL+1			;PRESSURE_REAL 10s and 1s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	1,1,10
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
	MOV	A, PRESSURE_REAL			;PRESSURE_REAL 0.1s and 0.01s
	CALL	BCD2ASCII
	__M_LCD_WRITEBUFFER	1,1,13
	MOV	A, B
	__M_LCD_APPENDBUFFER
	
USING	0
CYCLE_END:
	SETB	LED_IDEL
	JMP	WAIT
	

; INTERRUPT SERVICE ROUTINE ---------------------------------
USING	0
INT_0:
	RETI

USING	2
TIMER_0:						;Update LCD, R0 = LCD pointer
	CLR	TF0
	
	PUSH	ACC
	PUSH	PSW
	SETB	RS1
	CLR	RS0
	
	MOV	TH0, #0xF4				;Sample from ROV every 250000us, LCD samples from sample every 125000us
	MOV	TL0, #0x48				;(16+1)*2 LCD = 34chars --> Update LCD every 3000us (-3000 = 0xF448)
	
	MOV	A, R0					;Check LCD line end
	ANL	A, #0xF0				;Only look high part, which indecates the line number of the LCD data (LCD has 16 charcaters in one line)
	CLR	C
	SUBB	A, R7					;Compare with line number from last time
	JZ	TIMER_0_sendchar			;If same, send data char; otherwise, send line number
	
	TIMER_0_sendline:
	MOV	A, R0					;Update last line number
	ANL	A, #0xF0
	MOV	R7, A
	
	CLR	LCD_RS					;Send command to both LCDs
	SETB	LCD_E0
	SETB	LCD_E1
	RL	A					;ACC holds the current high 4 bits of the pointer to the LCD data (0x00 or 0x10)
	RL	A					;If A = 0x00: Send 0x80(10000000) (Set line 0); If A = 0x10: Send 0xC0(11000000) (Set line 1)
	ORL	A, #0x80
	MOV	LCD_DATA, A
	CLR	LCD_E0
	CLR	LCD_E1
	
	JMP	TIMER_0_end
	
	TIMER_0_sendchar:
	SETB	LCD_RS					;Set LCD mode = data
	
	MOVX	A, @R0					;Get data of LCD0
	SETB	LCD_E0
	MOV	LCD_DATA, A
	CLR	LCD_E0
	
	MOV	A, #0x20				;Get data from LCD1 buffer
	ADD	A, R0
	MOV	R1, A
	MOVX	A, @R1
	SETB	LCD_E1
	MOV	LCD_DATA, A
	CLR	LCD_E1
	
	INC	R0					;LCD data pointer ++
	ANL	AR0, #00011111B				;LCD data pointer mask (region 0x00-0x1F)
	
	TIMER_0_end:
	POP	PSW
	POP	ACC
	RETI

USING	0
INT_1:
	RETI

USING	0
TIMER_1:						;DO NOT USE! TIMER1 IS USED BY UART AS BAUD RATE GENERATOR.
	CLR	TF1
	RETI

USING	3
UART:							;Tx/Rx interrupt, R0 = Tx pointer, R1 = Rx pointer
	PUSH	ACC
	PUSH	PSW
	SETB	RS1
	SETB	RS0
	
	JBC	RI, UART_rxc				;Check interrupt reason
	JBC	TI, UART_txc
	JMP	UART_end
	
UART_txc:
	CJNE	R0, #TX_BUFFER+16, uart_txc_send	;Is package fully send?
	JMP	UART_end
	
	UART_txc_send:
	MOVX	A, @R0					;Get data from buffer and send to UART
	MOV	SBUF, A
	INC	R0					;Pointer inc
	
	;Notice: Tx can only be triggered by main routine when SYNCH signal fired, and the SYNCH signal will first reset the write pointer;
	;	hence, it is impossible to have the Tx buffer overflow.
	;	Even if the Tx overflow and sending some random data to the ROV, the ROV will ignor them.
	
	JMP	UART_end
	
UART_rxc:
	CLR	A					;Reset Rx package timeout counter
	XCH	A, RX_PAKTIMEOUT
	ADD	A, #-5					;Timeout? If timeout, it means new package
	JNC	UART_rxc_data				;If timeout, RX_PAKTIMEOUT > 5, (5+i) + (unsigned)(-5) will overflow
	
	UART_rxc_sync:
	MOV	A, SP					;Write return PC to MAIN
	ADD	A, #-3					;Stack = (H) PSW(Current pointer), ACC, PC_H, PC_L (L)
	MOV	R0, A
	MOV	@R0, #LOW MAIN
	INC	R0
	MOV	@R0, #HIGH MAIN
	JMP	UART_end
	
	UART_rxc_data:
	XCH	A, R1					;Rollback pointer if overflow
	JNZ	UART_rxc_receive			;Rx buffer is located in XRAM 0xF0 to 0xFF. If Rx pointer becomes 0x00, it means the Rx buffer overflowed
	DEC	R1					;In this case, the last word in the buffer will be overwrite
	
	UART_rxc_receive:
	MOV	A, SBUF
	MOVX	@R1, A					;Save the word in buffer
	INC	R1					;Pointer ++
	
UART_end:
	POP	PSW
	POP	ACC
	RETI

USING	0
TIMER_2:
	CLR	TF2
	CLR	EXF2
	
	PUSH	ACC
	PUSH	PSW
	
	MOV	A, RX_PAKTIMEOUT
	INC	A
	JNZ	TIMER_2_nonoverflow
	DEC	A
	TIMER_2_nonoverflow:
	MOV	RX_PAKTIMEOUT, A
	
	POP	PSW
	POP	ACC
	RETI

; CONSTANT DATA TABLES ---------------------------------
LCDTEMPLATE:
	DB "---P ---N --.--m"				;0-0 Pitch, Compass, Depth (dest)
	DB "M---  E---  >---"				;0-1 C_PWM, Input buffer
	DB "--.-V +--.-C  --"				;1-0 Voltage, Temperature, C_input
	DB "---P ---N --.--m"				;1-1 Pitch, Compass, Depth (real)

PITCH_VALIDVALUE:
	;If lookup[input] != 0: input is valid. Input range is 0x00 to 0x99
	;Valid: 0x00-0x09, 0x27-0x29, 0x30-0x35
	;  x0   x1   x2   x3   x4   x5   x6   x7   x8   x9   xA   xB   xC   xD   xE   xF
	DB 0x0A,0x01,0x02,0x03,0x04,0x05,0x06,0x07,0x08,0x09,0x00,0x00,0x00,0x00,0x00,0x00 ;0
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ;1
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x07,0x08,0x09,0x00,0x00,0x00,0x00,0x00,0x00 ;2
	DB 0x0A,0x01,0x02,0x03,0x04,0x05,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ;3
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ;4
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ;5
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ;6
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ;7
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00 ;8
	DB 0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00                               ;9

END;
