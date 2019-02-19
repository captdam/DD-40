The ROV and the Operator will comunicate every 1/4s.

There is a timer on the ROV, that overflows every 250ms.
When the timer on the ROV overflows, the ROV will do so:
	1. Check data in the receiver buffer (verify the data by checksum).
	2. If the data is verified, the ROV will update its app SFRs; otherwise, skip this step.
	3. The ROV will flush both receiver and transmitter buffers.
	4. The ROV will scan its app SFRs, and put the values into transmitter buffer.
	5. The ROV will first send a 0xFF byte (synch), then send all data in its transmitter buffer.

The package looks like this
	ROV --> Controller	0xFF - Data - Data - Data - ... - Data - Checksum
	Controller --> ROV	Data - Data - Data - ... - Data - Checksum
	See image (USART package.jpg) for package structure.

About synch:
	There is difference between the ROV's clock and Operator's clock. The error is very small, it is fine for short time operation; however, if the error accumulated by time, these will be a big issue. _(:3 _| <)__
	To deal with the synch problem, the ROV and Operator will do so: (ROV acts as master clock)
	1. The ROV will send package to Operator via UART every 1/4s, and the first word in the package is always 0xFF.
	2. If the Operator read 0xFF from the ROV, it means SYNCH. The Operator will then flush its buffers, read data from the ROV, send command to the ROV.
	Notice: The ROV send data to Operator in BCD format, hence, there is no data with the value of 0xFF. That means, when there is a 0xFF, it must be synch signal.
