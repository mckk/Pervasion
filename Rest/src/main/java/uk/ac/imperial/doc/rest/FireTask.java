package uk.ac.imperial.doc.rest;

import java.util.HashMap;
import java.util.HashSet;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;

public class FireTask extends TimerTask {

    // Period in milliseconds for which the task waits for other
    // nodes in indicate fire
    private static final int WAIT_PERIOD = 30000;

    // Reference to client object responsible for sending fire messages
    private RESTClient client;

    // Indicates whether the task was already scheduled
    private boolean alreadyScheduled;

    // Timer used to schedule the task
    private Timer timer;

    // Keeps track of which sensors indicated
    private ConcurrentHashMap<Integer, Boolean>fireMap;

    public FireTask(RESTClient client) {
        super();
        this.client = client;
        timer = new Timer();
        alreadyScheduled = false;
        fireMap = new ConcurrentHashMap<Integer, Boolean>();
    }

    @Override
    public void run() {
        alreadyScheduled = false;
        try {
            client.postFireEvent(getSensorsReportingFire());
            resetFireMap();
        } catch (Exception e) {
            System.err.println("Error while sending fire message: \n" + e);
        }
    }

    /**
     * Notifies FireTask object about fire occurring
     * @param sensorId  id of the sensor which indicates fire
     */
    public void notifyAboutFire(Integer sensorId) {

        // update fire map
        fireMap.put(sensorId, true);

        // scheduler fire event
        if (!alreadyScheduled) {
            alreadyScheduled = true;
            timer.schedule(this, WAIT_PERIOD);
        }
    }


   /*
    * Resets fire map (i.e. map which keeps record of sensors that
    * indicated fire event
    */
    private void resetFireMap() {
        for (Integer key : fireMap.keySet()) {
            fireMap.put(key, false);
        }
    }

    /*
     * Returns the set of all sensors reporting fire
     */
    private HashSet<Integer> getSensorsReportingFire() {
        HashSet<Integer> sensorIds = new HashSet<Integer>();
        for (Integer key : fireMap.keySet()) {
            if (fireMap.get(key)) {
               sensorIds.add(key);
            }
        }
        return sensorIds;
    }

}
