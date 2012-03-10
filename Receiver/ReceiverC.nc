#include "Timer.h"
#include "../DataMsg.h"
#include "SerialMsg.h"
#include "../FireMsg.h"
#include "../TimerRestartMsg.h"

module ReceiverC
{
  uses interface Leds;
  uses interface Boot;

  //Timer for sync messages
  uses interface Timer<TMilli> as SyncTimer;
  
  //Radio controls
  uses interface SplitControl as AMControl;
  uses interface Receive as DataReceive;
  uses interface Receive as FireMsgReceive;
  uses interface Packet as TimerPacket;
  uses interface AMSend as TimerSend;


  //Serial controls
  uses interface SplitControl as SerialAMControl;
  uses interface Packet as SerialPacket;
  uses interface AMSend as SerialSend;
}
implementation
{
  enum {
    SYNC_PERIOD = 10000, // Set sync period to 10 seconds
  };
  
  bool AMBusy;
  // Datapkt for sync message 
  message_t datapkt;
  
  bool SerialAMBusy;
  // Datapkt for serial data message
  message_t serialpkt;

  event void Boot.booted()
  {
    call AMControl.start();
    call SerialAMControl.start();
    
    // Fire sync timer every SYNC_PERIOD seconds
    call SyncTimer.startPeriodic(SYNC_PERIOD);
  }
  
//-----------------TIMER EVENTS------------------------------------//
  event void SyncTimer.fired()
  {
    // On fired broadcast sync message
    TimerRestartMsg *pkt = NULL;
    pkt = (TimerRestartMsg *)(call TimerPacket.getPayload(&datapkt, sizeof(TimerRestartMsg)));
    pkt -> srcid = TOS_NODE_ID;
    if (!AMBusy && call TimerSend.send(AM_BROADCAST_ADDR, &datapkt, sizeof(TimerRestartMsg)) == SUCCESS){
      AMBusy = TRUE;
    }
  }

//-----------------RADIO EVENTS------------------------------------//
  event void AMControl.startDone(error_t err)
  {
    if (err == SUCCESS) {
      AMBusy = FALSE;
    }
  }
  
  event void AMControl.stopDone(error_t err)
  {
    if(err == SUCCESS) {
      AMBusy = TRUE;
    }
  }
  
  event void TimerSend.sendDone(message_t *msg, error_t error)
  {
    AMBusy = FALSE;
  }
  
  event message_t * FireMsgReceive.receive(message_t * msg, void * payload, uint8_t len)
  {
    FireMsg * fire_pkt = NULL;
    SerialMsg * s_pkt = NULL;

    if (len != sizeof(FireMsg)) {
      return msg;
    }
    
    fire_pkt = (FireMsg *) payload;

    s_pkt = (SerialMsg *)(call SerialPacket.getPayload(&serialpkt, sizeof(SerialMsg)));
    
    s_pkt->header      = SERIALMSG_HEADER;
    s_pkt->srcid       = fire_pkt->srcid;
    s_pkt->fire        = TRUE;
    s_pkt->temperature = 0;
    s_pkt->lux         = 0;

    if (!SerialAMBusy && (call SerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(SerialMsg)) == SUCCESS)) {
      SerialAMBusy = TRUE;
    } 

    call Leds.led1Toggle();
    return msg;
  }

  event message_t * DataReceive.receive(message_t * msg, void * payload, uint8_t len)
  {
    SerialMsg * s_pkt = NULL;
    DataMsg * d_pkt = NULL;
    
    if(len != sizeof(DataMsg)) {
      return msg;
    }
    
    d_pkt = (DataMsg *) payload; 
    
    s_pkt = (SerialMsg *)(call SerialPacket.getPayload(&serialpkt, sizeof(SerialMsg)));
    
    s_pkt->header      = SERIALMSG_HEADER;
    s_pkt->srcid       = d_pkt->srcid;
    s_pkt->temperature = d_pkt->temp;
    s_pkt->lux         = d_pkt->lux;
    s_pkt->fire        = FALSE;
    
    if (!SerialAMBusy && (call SerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(SerialMsg)) == SUCCESS)) {
      SerialAMBusy = TRUE;
    } 

    call Leds.led0Toggle();
        
    return msg;
  }

//-----------------SERIAL EVENTS------------------------------------//
  event void SerialAMControl.stopDone(error_t err)
  {
    if(err == SUCCESS) {
      SerialAMBusy = TRUE;
    }
  }
  
  event void SerialAMControl.startDone(error_t err)
  {
    if (err == SUCCESS) {
      SerialAMBusy = FALSE;
    }
  }  
    
  event void SerialSend.sendDone(message_t *msg, error_t error)
  {
    SerialAMBusy = FALSE;
  }
  
}
