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
  uses interface Receive as TimerReceive;

  //Serial controls
  uses interface SplitControl as SerialAMControl;
  uses interface Packet as SerialPacket;
  uses interface AMSend as SerialSend;

  // Data queues
  uses interface Queue<FireMsg> as FireQueue;
  uses interface Queue<DataMsg> as DataQueue;
}
implementation
{
  enum {
    SYNC_PERIOD = 60000, // Set sync period to 60 seconds
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
  
//-----------------SYNC EVENTS------------------------------------//

  task void syncTimers()
  {
    if (!AMBusy) {
      TimerRestartMsg *pkt = NULL;
      pkt = (TimerRestartMsg *)(call TimerPacket.getPayload(&datapkt, sizeof(TimerRestartMsg)));
      pkt -> srcid = TOS_NODE_ID;
      if (call TimerSend.send(AM_BROADCAST_ADDR, &datapkt, sizeof(TimerRestartMsg)) == SUCCESS){
        AMBusy = TRUE;
      }
    }
  }
  
  event void SyncTimer.fired()
  {
    // On fired broadcast sync message
    post syncTimers();
  }
  
  event void TimerSend.sendDone(message_t *msg, error_t error)
  {
    if (&datapkt == msg) {
      AMBusy = FALSE;
    }
  }
  
  event message_t * TimerReceive.receive(message_t * msg, void * payload, uint8_t len)
  {
    post syncTimers();
    //I think we don't have to do next line. Should be ok without it.
    //call SyncTimer.startPeriodic(SYNC_PERIOD);
    return msg;
  }

// -----------------SEND MESSAGE TASKS-----------------------------------------//
  task void sendFireMessage() 
  {
    // declarations
    SerialMsg * s_pkt = NULL;
    FireMsg msg;
    FireMsg* fire_pkt;

    if (call FireQueue.empty()) {
      return;
    }

    // drain the queue
    msg = call FireQueue.dequeue();
    fire_pkt = &msg; 

    if(!SerialAMBusy) {
      // SerialAMBusy should never be true when the task is being called
      // but the check is included as the author is a defensive programmer

      s_pkt = (SerialMsg *)(call SerialPacket.getPayload(&serialpkt, sizeof(SerialMsg)));
      
      // Set the serial fire message
      s_pkt->header      = SERIALMSG_HEADER;
      s_pkt->srcid       = fire_pkt->srcid;
      s_pkt->fire        = TRUE;
      s_pkt->temperature = 0;
      s_pkt->lux         = 0;

      // Send the message
      if (call SerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(SerialMsg)) == SUCCESS) {
        SerialAMBusy = TRUE;
      } 

      // Toggle the led to indicate sending
      call Leds.led1Toggle();
    }
  }

  task void sendDataMessage() 
  {
    // declarations
    DataMsg d_msg;
    DataMsg* d_pkt;
    SerialMsg * s_pkt = NULL;

    if (call DataQueue.empty()) {
      return;
    }

    // Drain the queue
    d_msg = call DataQueue.dequeue();
    d_pkt = &d_msg;

    if(!SerialAMBusy) {
      // again, defensive programming, as this should not be true

      s_pkt = (SerialMsg *)(call SerialPacket.getPayload(&serialpkt, sizeof(SerialMsg)));
      
      // create serial msg
      s_pkt->header      = SERIALMSG_HEADER;
      s_pkt->srcid       = d_pkt->srcid;
      s_pkt->temperature = d_pkt->temp;
      s_pkt->lux         = d_pkt->lux;
      s_pkt->fire        = FALSE;
      
      // send serial msg
      if (call SerialSend.send(AM_BROADCAST_ADDR, &serialpkt, sizeof(SerialMsg)) == SUCCESS) {
        SerialAMBusy = TRUE;
      } 

      // toggle led to indicate sending
      call Leds.led0Toggle();
    }
  }


//-----------------DATA EVENTS------------------------------------//
  event void AMControl.startDone(error_t err)
  {
    if (err == SUCCESS) {
      AMBusy = FALSE;
      //sync timers on boot!
      post syncTimers();
    }
  }
  
  event void AMControl.stopDone(error_t err)
  {
    if(err == SUCCESS) {
      AMBusy = TRUE;
    }
  }
  
  event message_t * FireMsgReceive.receive(message_t * msg, void * payload, uint8_t len)
  {
    FireMsg* fire_pkt = NULL;

    if (len != sizeof(FireMsg)) {
      return msg;
    }
    fire_pkt = (FireMsg *) payload;

    if(!SerialAMBusy) {
      // if SerialAM is not busy, add the message to the queue
      // and post a task to send it 
      call FireQueue.enqueue(*fire_pkt);
      post sendFireMessage(); 
    }
    else {
      // else only add it to the queue, the queue will be drained 
      // when the current fire message finishes sending
      call FireQueue.enqueue(*fire_pkt); 
    }
    return msg;
  }

  event message_t * DataReceive.receive(message_t * msg, void * payload, uint8_t len)
  {
    DataMsg* d_pkt = NULL;

    if(len != sizeof(DataMsg)) {
      return msg;
    }
    d_pkt = (DataMsg *) payload;

    if(!SerialAMBusy) {
      // if SerialAM is not busy, add the message to the queue
      // and post a task to send it 
      call DataQueue.enqueue(*d_pkt);
      post sendDataMessage();
    }
    else {
      // else only add it to the queue, the queue will be drained 
      // when the current data message finishes sending
      call DataQueue.enqueue(*d_pkt);
    }
        
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
    if (!(call FireQueue.empty())) {
      // fire queue is not empty, post fireSend task
      post sendFireMessage();
    }
    else if (!(call DataQueue.empty())) {
      // else, data queue (lower priority) is not empty, so post dataSend
      post sendDataMessage(); 
    }
  }
  
}
