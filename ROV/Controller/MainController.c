#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>


/************************************************************************/
/* Config                                                               */
/************************************************************************/

#define RC_CLOCK_FREQ 1000000
#define RC_CLOCK_CALIBRATE 0xA0
#define UART_BAUD 2400
#define UART_BUFFERSIZE 16

#define ADC_BASEDATA_ADMUX ( (0<<REFS0) | (1<<ADLAR) ) //ADC left-adjust, using Vref (5V)
#define ADC_BASEDATA_ADCSRA ( (1<<ADEN) | (3<<ADPS0) ) //Enable ADC, , ADC clk = Sys clk / 8 = 125kHz (best range 50kHz-200kHz)
#define ADC_CH_VS 3
#define ADC_CH_DEPTH 2


/************************************************************************/
/* Application SFRs                                                     */
/************************************************************************/

//Communication sub-system transport layer
volatile uint8_t bufferTx[UART_BUFFERSIZE], bufferRx[UART_BUFFERSIZE] ,bufferTxIndex, bufferRxIndex;

//Sensor data
volatile uint16_t depthBCD, vsBCD, compassBCD, pitchBCD, temperatureBCD;
volatile uint8_t compass, pitch, temperature, cin;



/************************************************************************/
/* Code segment                                                         */
/************************************************************************/

//Polling ADC
uint8_t getVsBCD(uint8_t channel) {
	ADMUX = ADC_BASEDATA_ADMUX | (channel<<MUX0); //Select ADC channel
	ADCSRA = ADC_BASEDATA_ADCSRA | (1<<ADSC); //Start ADC
	while ( ADCSRA & (1<<ADSC) ); //Wait (by polling) until ADC finished
	return ADCH; //Get ADC result (MSB 8 bits)
}

//Init hardwares
int main(void) {
	//Init system clock
	CLKPR = 0x80;
	CLKPR = 0x03; //Clk divider = 8
	OSCCAL = RC_CLOCK_CALIBRATE;
	
	//Init UART
	UBRR0 = RC_CLOCK_FREQ/16/UART_BAUD-1;
	UCSR0B = (1<<RXCIE0) | (1<<TXCIE0) | (1<<RXEN0) | (1<<TXEN0); //Enable Tx, Rx, Tx interrupt and Rx interrupt
	UCSR0C = (1<<USBS0) | (3<<UCSZ00); //Async USART (UART), no parity, 2 stop bits, 8 bits data
	bufferTxIndex = 0;
	bufferRxIndex = 0;
	
	//Init I/O
	DDRD = 0x00;
	DDRB = 0xFF;
	
	//Init ADC
	ADMUX = ADC_BASEDATA_ADMUX;
	ADCSRA = ADC_BASEDATA_ADCSRA;
	DIDR0 = 0b00001111; //ADC channel 0 to 3 is for ADC only, disable the digital input buffer could reduce power consumption
	
	//Init I2C
	
	
	//Init timer0: the ROV exchange data with operator-side console every 250ms
	TCCR0A = 0b00000010; //CTC mode with OCR0A
	TCCR0B = 0b00000101; //Clk source = System clock / 1024
	OCR0A = 0xF4; //250000 / 1024 = 244.14 = 0xF4  <-- The clk doesn't need to be very accurate
	TIMSK0 = 0b00000010; //Enable Timer0 Compare match A interrupt ISR
	
	sei();
	
	for(;;) {
		
	}
}

//Main process <-- The main process of the ROV application, executed every 250ms
//All tasks in this ISR is guarantee to be done in 250ms
ISR (TIMER0_COMPA_vect) {
	
	/************************************************************************/
	/* STEP 1 - Polling packet from operator, if available and verified     */
	/************************************************************************/
	
	//Polling packet from operator-side console
	if (bufferRxIndex == UART_BUFFERSIZE) {
		uint8_t checksum = 0; //Calculate checksum
		for (uint8_t i = 0; i < UART_BUFFERSIZE; i++)
			checksum += bufferRx[i];
		
		if (!checksum) { //Update only if ckecksum OK
			
		}
	}
	
	//Reset UART buffer
	bufferTxIndex = 0;
	bufferRxIndex = 0;
	sei();
	
	/************************************************************************/
	/* STEP 2 - Get ROV status from sensors                                 */
	/************************************************************************/
	
	//From ADC sensor
	vsBCD = pgm_read_word(&(vsLookup[getVsBCD(ADC_CH_VS)]));
	depthBCD = pgm_read_word(&(depthLookup[getVsBCD(ADC_CH_DEPTH)]));
	
	//From I2C - MPU9250
	
	/************************************************************************/
	/* STEP 3 - Send ROV status to operatir-side console                    */
	/************************************************************************/
	
	//Send the first word (SYNC), following word will be send by TxC interrupt
	UDR0 = 0x00; //Note: Sending this signal takes 1/240s, the packet should be packed in this time
	
	bufferTx[0] = (uint8_t)(depthBCD & 0xFF);
	bufferTx[1] = (uint8_t)(depthBCD >> 8);
	bufferTx[2] = 0x00;
	bufferTx[3] = 0x00;
	bufferTx[4] = 0x00;
	bufferTx[5] = 0x00;
	bufferTx[6] = 0x00;
	bufferTx[7] = 0x00;
	bufferTx[8] = (uint8_t)(vsBCD & 0xFF);
	bufferTx[9] = (uint8_t)(vsBCD >> 8);
	bufferTx[10] = 0x00;
	//Word 11 to 14 not used
	
	//Send packet to operator
	uint8_t checksum = 0; //Get ckecksum
	for (uint8_t i = 0; i < UART_BUFFERSIZE-1; i++)
		checksum += bufferTx[i];
	bufferTx[UART_BUFFERSIZE-1] = 0 - checksum; //The last word of the packet is checksum
	
	/************************************************************************/
	/* STEP 4 - While sending packet, analysis user command                 */
	/************************************************************************/
	
	
	
	/************************************************************************/
	/* STEP 5 - A/P: Modify user command if AP enabled                      */
	/************************************************************************/
	
	
	
	
	/************************************************************************/
	/* STEP 6 - Send command to motors and valves                           */
	/************************************************************************/
	
	
	
	
}

ISR (USART_TX_vect) {
	if (bufferTxIndex < UART_BUFFERSIZE) //Send if index in buffer size range
		UDR0 = bufferTx[bufferTxIndex++];
}

ISR (USART_RX_vect) {
	if (bufferRxIndex < UART_BUFFERSIZE) //Prevent buffer overflow
		bufferRx[bufferRxIndex++] = UDR0;
}


/************************************************************************/
/* ROM consts, lookup tables                                            */
/************************************************************************/

const uint16_t vsLookup[256] PROGMEM = { //Battery voltage in BCD [TODO]
	//Vin = ADC_READ / 255 * 5.04 * (9.7k + 33k) / 9.7k
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131,
	0x0000,0x0008,0x0017,0x0026, 0x0034,0x0044,0x0052,0x0061, 0x0070,0x0078,0x0087,0x0096, 0x0104,0x0113,0x0122,0x0131
};

const uint16_t depthLookup[256] PROGMEM = { //Depth in BCD [TODO]
	//Depth(cm) = (ADC_READ / 5.06 - 0.493) / 3.2487 * 10
	
};
