#include <avr/io.h>
#include <avr/interrupt.h>


/************************************************************************/
/* Config                                                               */
/************************************************************************/

#define RC_CLOCK_FREQ 1000000
#define RC_CLOCK_CALIBRATE 0x40
#define UART_BAUD 9600

#define I2C_ADDR 0x05

#define PINCOUNT 12


/************************************************************************/
/* Code segment                                                         */
/************************************************************************/

volatile uint8_t pwm[PINCOUNT] ,pwmTimer;
volatile uint8_t buffer[PINCOUNT], bufferWritePtr;

//Init hardware
int main(void) {
	//Init system clock
	CLKPR = 0x80;
	CLKPR = 0x03; //Clk divider = 8
	OSCCAL = RC_CLOCK_CALIBRATE;
	
	//Init UART
	UBRR0 = RC_CLOCK_FREQ/16/UART_BAUD-1;
	UCSR0B = (0<<RXCIE0) | (0<<TXCIE0) | (1<<RXEN0) | (1<<TXEN0); //Enable Tx, Rx
	UCSR0C = (1<<USBS0) | (3<<UCSZ00); //Async USART (UART), no parity, 2 stop bits, 8 bits data
	
	//Init I/O
	DDRD = 0xFC; //765432
	DDRC = 0x0F; //3210, I2C on 54
	DDRB = 0xC0; //76
//	PORTC = 0x30; //Pull-up
	
	//Init I2C
	TWAR = (I2C_ADDR<<1)|0; //Set slave address, no general call
	TWCR = (1<<TWEA) | (1<<TWEN) | (1<<TWIE); //Enable I2C, ACK back, enable I2C interrupt
	
	//Init timer0: the AUX controller acts every 250/255ms, that is 980us
//	TCCR0A = 0b00000010; //CTC mode with OCR0A
//	TCCR0B = 0b00000010; //Clk source = System clock / 8
//	OCR0A = 0x7A; //980 / 8 = 122.5 = 0x7A (122)
//	TIMSK0 = 0b00000010; //Enable Timer0 Compare match A interrupt ISR
	
	//Reset software PWM counter
	for (uint8_t i = 0; i < 12; i++)
		pwm[i] = 0;
	pwmTimer = 0;
	bufferWritePtr = 0;
	
	sei();
	for(;;);
	return 0;
}

//Rceive from main controller
ISR(TWI_vect) {	
	uint8_t status = TWSR & 0xF8;
	
	//Start condition
	if (status == 0x60) {
		TWCR = (1<<TWINT) | (1<<TWEA) | (1<<TWEN) | (1<<TWIE); //Clear flag, enable I2C, ACK back, enable I2C interrupt
		bufferWritePtr = 0; //Reset write pointer
	}
	
	//Receive data, call WIP
	else if (status == 0x80) { //Addressed with own address, NAK or ACK returned
		PORTC |= 0x01;
		
		if (bufferWritePtr < PINCOUNT) { //Receive data: write to buffer
			buffer[bufferWritePtr++] = TWDR;
			TWCR = (1<<TWINT) | (1<<TWEA) | (1<<TWEN) | (1<<TWIE); //Clear flag, enable I2C, ACK back, enable I2C interrupt
		}
		
		else if (bufferWritePtr == PINCOUNT) { //Receive checksum
			bufferWritePtr++;
			
			uint8_t checksum = 0;
			for (uint8_t i = 0; i < PINCOUNT; i++)
				checksum += buffer[i];
			
			if (checksum + TWDR == 0x00) { //Checksum OK
				TWCR = (1<<TWINT) | (1<<TWEA) | (1<<TWEN) | (1<<TWIE); //Clear flag, enable I2C, ACK back, enable I2C interrupt
				for (uint8_t i = 0; i < PINCOUNT; i++)
					pwm[i] = buffer[i];
			}
			
			else //Checksum fail
				TWCR = (1<<TWINT) | (0<<TWEA) | (1<<TWEN) | (1<<TWIE); //Clear flag, enable I2C, NAK back, enable I2C interrupt
		}
		
		else //Write pointer overflow
			TWCR = (1<<TWINT) | (0<<TWEA) | (1<<TWEN) | (1<<TWIE); //Clear flag, enable I2C, NAK back, enable I2C interrupt
	}
	
	//Stop condition
	else if (status == 0xA0)
		TWCR = (1<<TWINT) | (1<<TWEA) | (1<<TWEN) | (1<<TWIE); //Clear flag, enable I2C, NAK back, enable I2C interrupt

	//Error
	else
		TWCR = (1<<TWINT) | (0<<TWEA) | (1<<TWEN) | (1<<TWIE); //Clear flag, enable I2C, NAK back, enable I2C interrupt
}

//Software PWM, frequency = 250ms (T = 122*8us * 255 = 976 * 255us = 248.88ms), resolution = 255
ISR(TIMER0_COMPA_vect) {
	
	//Order:	0   1   2   3   4   5   6   7   8   9   10  11
	//Pin#:		D2  D3  D4  B6  B7  D5  D6  D7  C3  C2  C1  C0
	//Port#:	4   5   6   9   10  11  12  13  26  25  24  23
	
	uint8_t b = 0x00, c = 0x00, d = 0x00; //Output of each port, 0 by default
	
	pwmTimer++;
	if (pwmTimer == (uint8_t)(-1)) //0x00 --> Always low, 0xFF --> Always high
		pwmTimer = 0;
	
	if (pwm[0] > pwmTimer) //If given PWM value greater than current timer, set that bit
		d |= 1 << 2; //Otherwise, leave that bit 0
	
	if (pwm[1] > pwmTimer) d |= 1 << 3;
	if (pwm[2] > pwmTimer) d |= 1 << 4;
	if (pwm[3] > pwmTimer) b |= 1 << 6;
	if (pwm[4] > pwmTimer) b |= 1 << 7;
	if (pwm[5] > pwmTimer) d |= 1 << 5;
	if (pwm[6] > pwmTimer) d |= 1 << 6;
	if (pwm[7] > pwmTimer) d |= 1 << 7;
	if (pwm[8] > pwmTimer) c |= 1 << 3;
	if (pwm[9] > pwmTimer) c |= 1 << 2;
	if (pwm[10] > pwmTimer) c |= 1 << 1;
	if (pwm[11] > pwmTimer) c |= 1 << 0;
	
	PORTB = b; //Update IO
	PORTC = c;
	PORTD = d;
}


