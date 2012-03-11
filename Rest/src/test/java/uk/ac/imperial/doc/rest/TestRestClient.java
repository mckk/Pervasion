package uk.ac.imperial.doc.rest;

import org.junit.Before;
import org.junit.Test;
import uk.ac.imperial.doc.helpers.SerialMsgBuilder;

public class TestRestClient {

    private RESTClient client = new RESTClient();

    //Serial messages
    private SerialMsg tempMsg;
    private SerialMsg luxMsg;
    private SerialMsgBuilder builder = new SerialMsgBuilder();

    @Before
    public void buildMessages() {
        tempMsg = builder.buildSerialMsg(35)
                .setTemperature((short)55)
                .returnMessage();
        luxMsg = builder.buildSerialMsg(33)
                .setLux((short)450)
                .returnMessage();
    }

    @Test
    public void testPostData() throws Exception {
        client.postDataSamples(tempMsg);
        client.postDataSamples(luxMsg);
    }
}
