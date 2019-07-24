// I2C module status code ------------------------------------------------

#define I2C_MODE_WRITE 0
#define I2C_MODE_READ 1
#define I2C_RETURN_NAK 0
#define I2C_RETURN_ACK 1
#define I2C_STATUS_START 0x08
#define I2C_STATUS_RESTART 0x10
#define I2C_STATUS_SLAWACK 0x18
#define I2C_STATUS_SLAWNAK 0x20
#define I2C_STATUS_DATATXACK 0x28
#define I2C_STATUS_DATATXNAK 0x30
#define I2C_STATUS_LOST 0x38
#define I2C_STATUS_SLARACK 0x40
#define I2C_STATUS_SLARNAK 0x48
#define I2C_STATUS_DATARXACK 0x50
#define I2C_STATUS_DATARXNAK 0x58


// Basic procedures ------------------------------------------------------

//Start I2C
uint8_t startI2C() {
	TWCR = (1<<TWINT) | (1<<TWSTA) | (1<<TWEN); //Start I2C
	while ( !(TWCR & (1<<TWINT)) ); //Wait until I2C started
	return TWSR & 0xF8; //Return status code
}

//Set I2C mode and slave address
uint8_t setI2C(uint8_t slaveAddr, uint8_t writeMode) {
	TWDR = (slaveAddr<<1) | writeMode; //TWDR[7:1] = slave address, TWDR[0] = 1 if write
	TWCR = (1<<TWINT) | (1<<TWEN); //Clear I2C finish flag and send address+mode
	while ( !(TWCR & (1<<TWINT)) ); //Wait until address and mode send
	return TWSR & 0xF8;
}

//Write on I2C bus
uint8_t writeI2C(uint8_t data) {
	TWDR = data;
	TWCR = (1<<TWINT) | (1<<TWEN); //Clear I2C finish flag (from last operation) and send new data
	while ( !(TWCR & (1<<TWINT)) ); //Wait until data send
	return TWSR & 0xF8;
}

//Read from I2C bus
uint8_t readI2C(uint8_t* data, uint8_t ack) { //Send ACK if there is any data need to be read after the current word in the current transaction
	if (ack)
	TWCR = (1<<TWEA) | (1<<TWINT) | (1<<TWEN); //Clear I2C finish flag (from last operation) and return ACK
	else
	TWCR = (1<<TWINT) | (1<<TWEN); //Clear I2C finish flag (from last operation) and return NAK
	while ( !(TWCR & (1<<TWINT)) ); //Wait for coming data
	*data = TWDR;
	return TWSR;
}

//Stop I2C
void stopI2C() {
	TWCR = (1<<TWINT) | (1<<TWSTO) | (1<<TWEN); //Clear I2C finish flag (from last operation) and send stop bit
}