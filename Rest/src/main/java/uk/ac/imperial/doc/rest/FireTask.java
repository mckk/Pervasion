package uk.ac.imperial.doc.rest;

import java.util.TimerTask;

public class FireTask extends TimerTask {

    private RESTClient client;

    public FireTask(RESTClient client) {
        super();
        this.client = client;
    }

    @Override
    public void run() {
        try {
            client.sendFireEvent();
        } catch (Exception e) {
            e.printStackTrace();  //TODO CHANGE
        }
        client.resetFireMap();
    }
}
