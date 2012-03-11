package uk.ac.imperial.doc.helpers;


import uk.ac.imperial.doc.rest.SerialMsg;

public class SerialMsgBuilder {

    private SerialMsg serialMsg;

    public SerialMsgBuilder buildSerialMsg(int nodeId) {
        serialMsg = new SerialMsg();
        serialMsg.set_srcid(nodeId);
        serialMsg.set_lux((short) 0);
        serialMsg.set_temperature((short) 0);
        serialMsg.set_fire((byte) 0);
        return this;
    }

    public SerialMsgBuilder setTemperature(short value) {
        if (serialMsg != null)
            serialMsg.set_temperature(value);
        return this;
    }

    public SerialMsgBuilder setLux(short value) {
        if (serialMsg != null)
            serialMsg.set_lux(value);
        return this;
    }

    public SerialMsgBuilder setFire(byte value) {
        if (serialMsg != null)
            serialMsg.set_fire(value);
        return this;
    }

    public SerialMsg returnMessage() {
        return serialMsg;
    }

}
