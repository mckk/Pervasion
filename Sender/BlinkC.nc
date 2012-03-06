//## Solution code for tutorial 3: (Sender Node Code)  of the wireless sensor network
//## programing module of the pervasive systems course.

#include "Timer.h"
#include "DataMsg.h"
#include "SerialMsg.h"

module BlinkC
{
  uses interface Timer<TMilli> as SensorTimer;
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
  bool temperatureRead;
  bool luxRead;


  event void Boot.booted()
  {
    temperature = 0;
    lux = 0;
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

    event message_t * DataReceive.receive(message_t * msg, void * payload, uint8_t len) {

      return msg;
    }



  task void sendData(){
    if(temperatureRead && luxRead){
		DataMsg *pkt = NULL;
		call Leds.led2On();
		
		pkt = (DataMsg *)(call DataPacket.getPayload(&datapkt, sizeof(DataMsg)));
		pkt->srcid          = TOS_NODE_ID;
		pkt->temp           = temperature;
		pkt->lux			= lux;

		if(!AMBusy){
			if(call DataSend.send(AM_BROADCAST_ADDR, &datapkt, sizeof(DataMsg)) == SUCCESS){
				AMBusy = TRUE;
			}
		}
	}
  }
  
  event void Temp_Sensor.readDone(error_t result, uint16_t data) {
    if(result == SUCCESS){
    	temperature = data;
		temperatureRead = TRUE;
		post sendData();
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

