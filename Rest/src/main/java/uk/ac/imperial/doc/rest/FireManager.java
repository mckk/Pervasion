package uk.ac.imperial.doc.rest;

import java.util.HashSet;
import java.util.Timer;
import java.util.TimerTask;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Semaphore;

public class FireManager {

    private final Semaphore timerSema = new Semaphore(1);

    // Period in milliseconds for which the task waits for other
    // nodes in indicate fire
    private static final int WAIT_PERIOD = 5000;

    // Reference to client object responsible for sending fire messages
    private RESTClient client;

    // Indicates whether the task was already scheduled
    private boolean alreadyScheduled;

    // Timer used to schedule the task
    private Timer timer;

    // Keeps track of which sensors indicated
    private ConcurrentHashMap<Integer, Boolean>fireMap;

    public FireManager(RESTClient client) {
        super();
        this.client = client;
        timer = new Timer();
        alreadyScheduled = false;
        fireMap = new ConcurrentHashMap<Integer, Boolean>();
    }

    /**
     * Notifies FireManager object about fire occurring
     * @param sensorId  id of the sensor which indicates fire
     */
    public synchronized void notifyAboutFire(Integer sensorId) {

        // update fire map
        fireMap.put(sensorId, true);

        // scheduler fire event
        if (!alreadyScheduled) {
            alreadyScheduled = true;

            // Another even may be in progress and so the task will not
            // be actually scheduled so a semaphore is needed to ensure
            // that the task will be scheduled
            try {
                timerSema.acquire();
                timer.schedule(new FireTask(), WAIT_PERIOD);
            } catch (InterruptedException e) {
                System.err.println("Exception occurred while waiting to schedule: " +
                        "\n" + e);
            }
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

    /*
     * An inner fire task class
     */
    private class FireTask extends TimerTask {

        @Override
        public void run() {

            alreadyScheduled = false;
            try {
                HashSet sensorIds = getSensorsReportingFire();
                if (!sensorIds.isEmpty()) {
                    resetFireMap();
                    client.postFireEvent(sensorIds);
                }
            } catch (Exception e) {
                System.err.println("Error while sending fire message: \n" + e);
            } finally {
                timerSema.release();
            }
        }
    }

}
