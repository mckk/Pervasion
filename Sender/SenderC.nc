#include "Timer.h"
#include "DataMsg.h"

module SenderC
{
  uses interface Timer<TMilli> as SensorTimer;
  uses interface Timer<TMilli> as GreenLedTimer;

  uses interface Leds;
  uses interface Boot;
  uses interface Read<uint16_t> as Temp_Sensor;
  uses interface Read<uint16_t> as Lux_Sensor;

  uses interface SplitControl as AMControl;
  uses interface Packet as DataPacket;
  uses interface AMSend as DataSend;
  uses interface Receive as DataReceive;

}
implementation
{

  enum {
  	SAMPLE_PERIOD = 1000,
    NEIGHBOURS_NUMBER = 2,
    LOG_SIZE = 30,  // log size should be even
  };

  uint16_t temperature;
  uint16_t lux;

  message_t datapkt;

  bool AMBusy;

  // Used to check when both checks are done
  bool temperatureRead;
  bool luxRead;

  // Used to store the last temperature readings
  uint16_t tempLog[LOG_SIZE];
  uint16_t curLogIndex;
  bool bufferFull;

  // used to store the lighting readings of neighbouring nodes
  bool neighboursLux[NEIGHBOURS_NUMBER];
  uint8_t luxIndex;
  
  // stores the id of the last neighbour who was communicating wih us;
  uint8_t lastNeighbourId; 


  event void Boot.booted()
  {
	int i;

	// initialize all variables
    temperature = 0;
    lux = 0;
    curLogIndex = 0;
    luxIndex = 0;
    temperatureRead = FALSE;
    luxRead = FALSE;
    bufferFull = FALSE;

	for (i = 0 ; i < LOG_SIZE ; i++) {
		tempLog[i] = 0;
	}
    for (i = 0 ; i < NEIGHBOURS_NUMBER ; i++) {
		neighboursLux[i] = FALSE;
	}

    call SensorTimer.startPeriodic(SAMPLE_PERIOD );
    call AMControl.start();
  }

  event void SensorTimer.fired()
  {
    call Temp_Sensor.read();
	call Lux_Sensor.read();
  }

  event void GreenLedTimer.fired(){
	call Leds.led1Toggle();
  }

   event void AMControl.stopDone(error_t err) {
        if(err == SUCCESS){
        }
    }
    
    event void AMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            AMBusy    = FALSE;
        }
    } 

    event void DataSend.sendDone(message_t * msg, error_t error) {
        if (&datapkt == msg) {
            AMBusy = FALSE;
            temperatureRead = FALSE;
			luxRead = FALSE;
        }

        call Leds.led2Off();
    }

	// for receiving messages from other nodes
    event message_t * DataReceive.receive(message_t * msg, void * payload, uint8_t len) {
	  DataMsg * d_pkt = NULL;

      if(len == sizeof(DataMsg)) {
        d_pkt = (DataMsg *) payload;
		if(d_pkt->lux < 100){
		  call Leds.led1Toggle();
		  call GreenLedTimer.startOneShot(20);
		} 

		// write the received lux reading to the buffer
        if (lastNeighbourId != d_pkt->srcid) {
			lastNeighbourId = d_pkt->srcid;
			luxIndex = 1 - luxIndex;  
		}
		neighboursLux[luxIndex] = d_pkt->lux < 100;
      } 
        
      return msg;
    }


  // If both temperature and light readings occured, send the data
  task void sendData(){
    if(temperatureRead && luxRead){
		DataMsg *pkt = NULL;
		call Leds.led2On();
	
		pkt = (DataMsg *)(call DataPacket.getPayload(&datapkt, sizeof(DataMsg)));
		pkt->srcid          = TOS_NODE_ID;
		pkt->temp           = temperature;
		pkt->lux	        = lux;

		if(!AMBusy){
			if(call DataSend.send(AM_BROADCAST_ADDR, &datapkt, sizeof(DataMsg)) == SUCCESS){
				AMBusy = TRUE;
			}
		}
	}
  }

  // Checks for fire condition, if the fire is detected, flashes red 
  // light and sends alert message to the remote mote
  task void checkForFire() {

	// Declare all vars
	int index = 0;
	int sumOne = 0;
	int sumTwo = 0;
	int avgOne = 0;
	int avgTwo = 0;
	int splitIndex;
	bool isDark = TRUE;

    // The first condition is that all nodes detect that it is currently dark
    if (lux < 100) {
		// Check for neighbours 
		for ( ; index < NEIGHBOURS_NUMBER; index++) {
			// if the reading actually occured
			isDark = isDark && neighboursLux[index];
		}
	}

	if (!isDark) {
		// not dark, terminate task
		return;
	}

	// The second condition is to check whether there is an increase in temperature
	
	// Split the buffer into two arrays
	splitIndex = (curLogIndex + LOG_SIZE/2) % LOG_SIZE; 
	
	// Compute average of each array
	index = curLogIndex;

	sumOne = 0;
	for ( ; index != splitIndex ; ) {
		sumOne = sumOne + tempLog[index];
		index = (index + 1) % LOG_SIZE;
	}
	
	sumTwo = 0;
	for ( ; index != curLogIndex ; ) {
		sumTwo = sumTwo + tempLog[index];
		index = (index + 1) % LOG_SIZE;
	}

	avgOne = sumOne/(LOG_SIZE/2);
	avgTwo = sumTwo/(LOG_SIZE/2);

	if (avgOne + 20 < avgTwo) {
		// we have fire
		
	}

  }
  
  event void Temp_Sensor.readDone(error_t result, uint16_t data) {
    if(result == SUCCESS){
    	temperature = data;
		temperatureRead = TRUE;
		post sendData();

		// write the temperature to the log
		tempLog[curLogIndex] = temperature;
		
		// check if the buffer is full
		if (curLogIndex == LOG_SIZE) {
			bufferFull = TRUE;
		}
        curLogIndex = (curLogIndex + 1) % LOG_SIZE;

        // post task to check for fire
		if (bufferFull) {
			post checkForFire();
		}
    } 
  }

  event void Lux_Sensor.readDone(error_t result, uint16_t data){
 	if(result == SUCCESS){
		lux = data;
		luxRead = TRUE;
		post sendData();
	}
  }



}

