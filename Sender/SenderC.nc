#include "Timer.h"
#include "../DataMsg.h"
#include "../FireMsg.h"
#include "../TimerRestartMsg.h"

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
  
  uses interface AMSend as FireMsgSend;

  uses interface Receive as TimerReceive;
  uses interface Packet as TimerPacket;
  uses interface AMSend as TimerSend;

}
implementation
{

  enum {
    SAMPLE_PERIOD     = 1000,
    NEIGHBOURS_NUMBER = 2,    // the number of neighbour nodes
    LOG_SIZE          = 30,   // log size should be even
    BASE_ADDR         = 0x22, // the address of base station
  };

  // used to store sensor's readings
  uint16_t temperature;
  uint16_t lux;

  // Used to check when both checks are done
  bool temperatureRead;
  bool luxRead;
  
  // used for messaging
  message_t datapkt;
  bool AMBusy;
  
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
    lastNeighbourId = 0;
    temperatureRead = FALSE;
    luxRead = FALSE;
    bufferFull = FALSE;

    // initialize the values of all arrays
    for (i = 0 ; i < LOG_SIZE ; i++) {
      tempLog[i] = 0;
    }
    
    for (i = 0 ; i < NEIGHBOURS_NUMBER ; i++) {
      neighboursLux[i] = FALSE;
    }
    
    call AMControl.start();
  }
  

//-----------------SYNC EVENTS------------------------------------//

  // for receiving syncMessages
  event message_t * TimerReceive.receive(message_t * msg, void * payload, uint8_t len)
  {
    if(len == sizeof(TimerRestartMsg)) {
      call SensorTimer.startPeriodic(SAMPLE_PERIOD);
    }
    return msg;
  }
  
  task void syncTimers()
  {
    if (!AMBusy) {
      TimerRestartMsg *pkt = NULL;
      pkt = (TimerRestartMsg *)(call TimerPacket.getPayload(&datapkt, sizeof(TimerRestartMsg)));
      pkt -> srcid = TOS_NODE_ID;
      if (call TimerSend.send(BASE_ADDR, &datapkt, sizeof(TimerRestartMsg)) == SUCCESS){
        AMBusy = TRUE;
      }
    }
  }
  
  event void TimerSend.sendDone(message_t *msg, error_t error)
  {
    if (&datapkt == msg) {
      AMBusy = FALSE;
    }
  }
  
//---------------BORING STUFF--------------------------------//
  event void AMControl.stopDone(error_t err)
  {
    if(err == SUCCESS){
      AMBusy = TRUE;
    }
  }

  event void AMControl.startDone(error_t err)
  {
    if (err == SUCCESS) {
      AMBusy = FALSE;
      post syncTimers();
    }
  }
  
//--------------DATA EVENTS-----------------------------------//

  event void SensorTimer.fired()
  {
    call Temp_Sensor.read();
    call Lux_Sensor.read();
  }

  event void GreenLedTimer.fired()
  {
    call Leds.led1Toggle();
  }
  
  event void DataSend.sendDone(message_t * msg, error_t error)
  {
    if (&datapkt == msg) {
      AMBusy = FALSE;
      temperatureRead = FALSE;
      luxRead = FALSE;
    }
    call Leds.led2Off();
  }

  event void FireMsgSend.sendDone(message_t * msg, error_t error)
  {
    if (&datapkt == msg) {
      AMBusy = FALSE;
    }
  }

  // for receiving messages from other nodes
  event message_t * DataReceive.receive(message_t * msg, void * payload, uint8_t len)
  {
    DataMsg * d_pkt = NULL;
    if(len == sizeof(DataMsg)) {
      d_pkt = (DataMsg *) payload;
      if(d_pkt->lux < 100) {
        call Leds.led1Toggle();
        call GreenLedTimer.startOneShot(20);
      }
      // write the received lux reading to the buffer
      if (lastNeighbourId != d_pkt->srcid) {
        lastNeighbourId = d_pkt->srcid;
        luxIndex = 1 - luxIndex;
      }
      // flag whether any neighbour indicates dark
      neighboursLux[luxIndex] = d_pkt->lux < 100;
    }
    return msg;
  }
    
  // If both temperature and light readings occured, send the data
  task void sendData()
  {
    if(temperatureRead && luxRead && !AMBusy) {
      DataMsg *pkt = NULL;
      call Leds.led2On();
      
      pkt = (DataMsg *)(call DataPacket.getPayload(&datapkt, sizeof(DataMsg)));
      pkt->srcid          = TOS_NODE_ID;
      pkt->temp           = temperature;
      pkt->lux	          = lux;
      
      if(call DataSend.send(AM_BROADCAST_ADDR, &datapkt, sizeof(DataMsg)) == SUCCESS) {
        AMBusy = TRUE;
      }
    }
  }

  // Checks for fire condition, if the fire is detected, flashes red 
  // light and sends alert message to the remote mote
  task void checkForFire()
  {
    // Declare all vars
    int index = 0;
    int sumOne = 0;
    int sumTwo = 0;
    int avgOne = 0;
    int avgTwo = 0;
    int splitIndex;
    bool areNeighboursDark = TRUE;
    bool isFire = FALSE;
    FireMsg *pkt = NULL;
    
    // The first condition is that all nodes detect that it is currently dark
    // Check that all neighbours are dark
    for ( ; index < NEIGHBOURS_NUMBER; index++) {
      // if the reading actually occured
      areNeighboursDark = areNeighboursDark && neighboursLux[index];
    }

    if (areNeighboursDark && lux < 100) {
      // all nodes are in the dark
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
        // turn on red led
        call Leds.led0On();
        isFire = TRUE;

        if(!AMBusy) {
          // send the fire message
          pkt = (FireMsg *)(call DataPacket.getPayload(&datapkt, sizeof(FireMsg)));
          pkt->srcid = TOS_NODE_ID;

          if(call FireMsgSend.send(BASE_ADDR, &datapkt, sizeof(FireMsg)) == SUCCESS){
            AMBusy = TRUE;
          }
        }
      }
    } 
    if (!isFire) {
      // fire may be over, ensure that the red ligh is turned off
      call Leds.led0Off();
    }
  }
  
  event void Temp_Sensor.readDone(error_t result, uint16_t data)
  {
    if(result == SUCCESS){
      temperature = data;
      temperatureRead = TRUE;
      post sendData();

      // write the temperature to the log
      tempLog[curLogIndex] = temperature;
      
      // check if we already had LOG_SIZE readings of temperature
      // if not, we do not want to check for fire
      if (curLogIndex == LOG_SIZE - 1) {
        bufferFull = TRUE;
      }
      curLogIndex = (curLogIndex + 1) % LOG_SIZE;

      // post task to check for fire
      if (bufferFull) {
        post checkForFire();
      }
    } 
  }

  event void Lux_Sensor.readDone(error_t result, uint16_t data)
  {
    if(result == SUCCESS){
      lux = data;
      luxRead = TRUE;
      post sendData();
    }
  }

}

