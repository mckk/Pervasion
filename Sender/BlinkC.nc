#include "Timer.h"
#include "DataMsg.h"

module BlinkC
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

  uint16_t SAMPLE_PERIOD = 1000;

  uint16_t temperature;
  uint16_t lux;

  message_t datapkt;

  bool AMBusy;

  // Used to check when both checks are done
  bool temperatureRead;
  bool luxRead;

  uint16_t tempLog[30];
  uint16_t curLogIndex;

  uint16_t neighboursLux[2];
  uint8_t luxIndex;
  
  // stores the id of the last neighbour who was communicating wih us;
  uint8_t lastNeighbourId; 


  event void Boot.booted()
  {
    temperature = 0;
    lux = 0;
    curLogIndex = 0;
    luxIndex = 0;
    temperatureRead = FALSE;
    luxRead = FALSE;
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
        lastNeighbourId = d_pkt->srcid;
		neighboursLux[luxIndex] = d_pkt->lux;
        luxIndex = 1 - luxIndex;  
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
		pkt->lux	      = lux;

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
  	
    // TODO how to measure the increase in temperature
  }
  
  event void Temp_Sensor.readDone(error_t result, uint16_t data) {
    if(result == SUCCESS){
    	temperature = data;
		temperatureRead = TRUE;
		post sendData();

		// write the temperature to the log
		tempLog[curLogIndex] = temperature;
        curLogIndex = curLogIndex + 1;

        // post task to check for fire
		post checkForFire();
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

