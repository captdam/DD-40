; LCD instruction

__M_LCD_INI		MACRO	CMD			;Write instruction to both LCDs
		CLR	LCD_RS
		SETB	LCD_E0
		SETB	LCD_E1
		MOV	LCD_DATA, CMD
		CLR	LCD_E0
		CLR	LCD_E1
	ENDM

__M_LCD_PREPARE		MACRO
	__M_LCD_INI #0x38				;8-bit interface, 2-line, 5*8 font
	CALL	WAIT5000
	__M_LCD_INI #0x38
	CALL	WAIT100
	__M_LCD_INI #0x08				;Cursor display off
	CALL	WAIT100
	__M_LCD_INI #0x01				;Clear display
	CALL	WAIT5000
	__M_LCD_INI #0x06				;Cursor auto-inc (left-to-right write)
	CALL	WAIT100
	__M_LCD_INI #0x0C				;Turn on display
	CALL	WAIT100
	ENDM


__M_LCD_WRITEBUFFER	MACRO	LCD, LINE, INDEX
	MOV	R0,	#LCD*0x20+LINE*0x10+INDEX+LCD_BUFFER
	MOVX	@R0, A
	ENDM

__M_LCD_APPENDBUFFER	MACRO
	INC	R0
	MOVX	@R0, A
	ENDM

BCD2ASCII:
	; Input: A(InputBCD)
	; Output: A(High), B(Low) - To convenient the LCD buffer, A will hold high value and B will hold low value here
	; Modify: A, B
	MOV	B, A
	ANL	A, #0x0F
	ORL	A, #0x30
	XCH	A, B
	ANL	A, #0xF0
	SWAP	A
	ORL	A, #0x30
	RET

BCDHIGH2ASCII:
	; Input: A(InputBCD)
	; Output: A(High)
	; Modify: A
	ANL	A, #0xF0
	SWAP	A
	ORL	A, #0x30
	RET

BCDLOW2ASCII:
	; Input: A(InputBCD)
	; Output: A(High)
	; Modify: A
	ANL	A, #0x0F
	ORL	A, #0x30
	RET