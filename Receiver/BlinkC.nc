//## Solution code for tutorial 3: (Receiver Node code) of the wireless sensor network
//## programing module of the pervasive systems course.

#include "Timer.h"
#include "DataMsg.h"
#include "SerialMsg.h"

module BlinkC
{
  uses interface Leds;
  uses interface Boot;

  ///* Solution 2, implement the Radio stack.
  uses interface SplitControl as AMControl;
  uses interface Packet as DataPacket;
  uses interface AMSend as DataSend;
  uses interface Receive as DataReceive;

  ///* Solution 3, implement the Serial stack.
  uses interface SplitControl as SerialAMControl;
  uses interface Packet as SerialPacket;
  uses interface AMSend as SerialSend;
  uses interface Receive as SerialReceive;
}
implementation
{

  uint16_t temperature_value;
  uint16_t lux_value;

  message_t datapkt;
  bool AMBusy;
  
  message_t serialpkt;
  bool SerialAMBusy;

  event void Boot.booted()
  {
    temperature_value = 0;
    lux_value = 0;

    call AMControl.start();

    call SerialAMControl.start();
  }

   event void AMControl.stopDone(error_t err) {
        if(err == SUCCESS){
	    AMBusy = TRUE;
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
        }
        
    }

    event message_t * DataReceive.receive(message_t * msg, void * payload, uint8_t len) {
      SerialMsg * s_pkt = NULL;
      DataMsg * d_pkt = NULL;
        
      if(len == sizeof(DataMsg)) {
        d_pkt = (DataMsg *) payload;      
      }       
      
      s_pkt = (SerialMsg *)(call SerialPacket.getPayload(&serialpkt, sizeof(SerialMsg)));
        
      s_pkt->header      = SERIALMSG_HEADER;
      s_pkt->srcid       = d_pkt->srcid;
      s_pkt->temperature = d_pkt->temp;
      s_pkt->lux         = d_pkt->lux;
      
      if(SerialAMBusy) {      
      } else {
        if (call SerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(SerialMsg)) == SUCCESS) {
            SerialAMBusy = TRUE;
        }
      } 

      call Leds.led0Toggle();
        
      return msg;
    }


    event void SerialAMControl.stopDone(error_t err) {
        if(err == SUCCESS){
        }
    }
    
    event void SerialAMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            SerialAMBusy    = FALSE;
        }
    } 
    event void SerialSend.sendDone(message_t *msg, error_t error) {
        SerialAMBusy = FALSE;
    }

    event message_t * SerialReceive.receive(message_t * msg, void * payload, uint8_t len) {
        return msg; 
    }
}
