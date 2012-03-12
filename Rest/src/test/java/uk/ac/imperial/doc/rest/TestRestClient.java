package uk.ac.imperial.doc.rest;

import org.junit.Before;
import org.junit.Test;
import uk.ac.imperial.doc.helpers.SerialMsgBuilder;

import java.util.HashSet;

public class TestRestClient {

    private RESTClient client = new RESTClient();

    //Serial messages
    private SerialMsg tempMsg;
    private SerialMsg luxMsg;
    private SerialMsg mixedMsg;
    private SerialMsgBuilder builder = new SerialMsgBuilder();

    @Before
    public void buildMessages() {
        tempMsg = builder.buildSerialMsg(35)
                .setTemperature((short)490)
                .returnMessage();
        luxMsg = builder.buildSerialMsg(33)
                .setLux((short)450)
                .returnMessage();
        mixedMsg = builder.buildSerialMsg(36)
                .setLux((short)178)
                .setTemperature((short)492)
                .returnMessage();
    }

    @Test
    public void testPostData() throws Exception {
        client.postDataSamples(tempMsg);
        client.postDataSamples(luxMsg);
        client.postDataSamples(mixedMsg);
    }

    @Test
    public void testPostFire() throws Exception {
        HashSet<Integer> set1 = new HashSet<Integer>();
        set1.add(0);
        set1.add(1);
        set1.add(2);

        client.postFireEvent(set1);
    }
}
