//#ifndef FIREMSG_H
#define FIREMSG_H

enum {
	AM_FIREMSG		= 10,
    FIREMSG_HEADER  = 0x99,
};

typedef nx_struct FireMsg {
    nx_uint8_t srcid;
} FireMsg;
