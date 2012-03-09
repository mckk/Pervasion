#include "Timer.h"
#include "../DataMsg.h"
#include "SerialMsg.h"
#include "../FireMsg.h"

module ReceiverC
{
  uses interface Leds;
  uses interface Boot;

  uses interface SplitControl as AMControl;
  uses interface Receive as DataReceive;

  uses interface SplitControl as SerialAMControl;
  uses interface Packet as SerialPacket;
  uses interface AMSend as SerialSend;

  uses interface Receive as FireMsgReceive;  
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
	  s_pkt->fire 		 = FALSE;
            
      if (!SerialAMBusy && (call SerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(SerialMsg)) == SUCCESS)) {
      	SerialAMBusy = TRUE;
      } 

      call Leds.led0Toggle();
        
      return msg;
    }

	event message_t * FireMsgReceive.receive(message_t * msg, void * payload, uint8_t len) {
		FireMsg * fire_pkt = NULL;
      	SerialMsg * s_pkt = NULL;

		if (len == sizeof(FireMsg)) {
			fire_pkt = (FireMsg *) payload;
		}

      	s_pkt = (SerialMsg *)(call SerialPacket.getPayload(&serialpkt, sizeof(SerialMsg)));
        
     	s_pkt->header      = SERIALMSG_HEADER;
      	s_pkt->srcid       = fire_pkt->srcid;
		s_pkt->fire 	   = TRUE; 
     	s_pkt->temperature = 0;
      	s_pkt->lux         = 0;

     	if (!SerialAMBusy && (call SerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(SerialMsg)) == SUCCESS)) {
      		SerialAMBusy = TRUE;
      	} 

      	call Leds.led1Toggle();

		return msg;
	}


    event void SerialAMControl.stopDone(error_t err) {
        if(err == SUCCESS){
        }
    }
    
    event void SerialAMControl.startDone(error_t err) {
        if (err == SUCCESS) {
            SerialAMBusy = FALSE;
        }
    } 
    event void SerialSend.sendDone(message_t *msg, error_t error) {
        SerialAMBusy = FALSE;
    }
}
