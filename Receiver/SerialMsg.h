#ifndef SERIALMSG_H
#define SERIALMSG_H

enum {
    AM_SERIAL         = 11,
    AM_SERIALMSG      = 11,
    SERIALMSG_HEADER  = 0x9F,
};

typedef nx_struct SerialMsg {
    nx_uint8_t  header;
    nx_uint16_t srcid;
    nx_int16_t  temperature;
    nx_int16_t  lux;
} SerialMsg;
#endif

