package uk.ac.imperial.doc.rest;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Date;
import java.util.HashMap;
import java.util.Set;
import java.util.concurrent.ArrayBlockingQueue;
import java.util.concurrent.ConcurrentHashMap;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.restlet.data.*;
import org.restlet.representation.Representation;
import org.restlet.representation.StringRepresentation;
import org.restlet.resource.ClientResource;


/**
 * REST client main class
 */
public class RESTClient {

    // Data collection IP addresses.
    @SuppressWarnings("unused")
    private static final String dataCollectionAddr1 = "146.169.37.100";
    private static final String dataCollectionAddr2 = "146.169.37.101";
    private static final String dataCollectionAddr3 = "146.169.37.102";
    private static final String dataCollectionAddr4 = "146.169.37.103";

    private static final String dbAddr              = "146.169.37.133";

    // Group info
    private static final String groupID = "9";
    private static final String APIKey = "fRrefHtp";
    private static final String groupName = "Pervasion";

    // Number of nodes
    private static final int NODES_NUM = 3;

    // Number of couch db request to queue
    private static final int REQUEST_NUM = 1000;

    // RESTlet resource objects
    private ClientResource energyDataSampleClientResource;
    private ClientResource energyEventClientResource;
    private ClientResource couchDBResource;

    // Mapping from node id to sensor id
    private HashMap<Integer, Integer> sensorNodeMapping;
    private int mappingCounter = 0;

    // Indicating which nodes reported fire
    private ConcurrentHashMap<Integer, Boolean> fireMap;

    // CouchDB child thread for updating database
    private CouchDBThread couchThread;

    public RESTClient() {

        // Initialize client resource objects
        String energyDataURL = "http://" + dataCollectionAddr1 + ":8080/energy-data-service/energyInfo/dataSample";
        String energyEventURL = "http://" + dataCollectionAddr1 + ":8080/energy-data-service/energyInfo/event";
        String dbAddress = "http://" + dbAddr + ":5984/sensor_data/_bulk_docs";

        energyDataSampleClientResource = new ClientResource(energyDataURL);
        energyEventClientResource = new ClientResource(energyEventURL);

        couchDBResource = new ClientResource(dbAddress);

        // set the accept header to application/json
        energyDataSampleClientResource.getClientInfo().getAcceptedMediaTypes().add(new Preference<MediaType>(MediaType.APPLICATION_JSON));
        energyEventClientResource.getClientInfo().getAcceptedMediaTypes().add(new Preference<MediaType>(MediaType.APPLICATION_JSON));
        couchDBResource.getClientInfo().getAcceptedMediaTypes().add(new Preference<MediaType>(MediaType.APPLICATION_JSON));

        // Add client authentication to couchDB
        ChallengeScheme scheme = ChallengeScheme.HTTP_BASIC;
        ChallengeResponse authentication = new ChallengeResponse(scheme, "admin", APIKey);
        couchDBResource.setChallengeResponse(authentication);

        // initialize sensor-node mapping
        sensorNodeMapping = new HashMap<Integer, Integer>();

        // initialize couchdb thread
        couchThread = new CouchDBThread();
        couchThread.start();
    }

    /**
     * Post reading sample to data collection unit and couch db instance
     * @param message  serial message representing sensor's reading
     * @throws Exception  throws exception when posting data fails
     */
    public void postDataSamples(SerialMsg message) throws Exception {



        /*
           *  POST /energyInfo/dataSample - Send one or more samples of data from your sensors
           *  Accept content: application/json
           *  Parameters:
           *  groupId: string 					Your group number
           *  key: string							API "key" as provided per group
           *  groupName: string (optional)		An optional name for your group
           *  sensorData: array					An array of one or more sensor data samples objects.
           *  	Structure of sensor data:
           *  	sensorId: number				Either 0,1 or 2 depending on sampled sensor
           *  	nodeId: number (optional)		The number of the node that has generated this reading
           *  	timestamp: number				Timestamp for the reading in milliseconds since the epoch
           *  	temp: number double)			Temperature value from sensor OR null if a lux value is provided
           *  	lux: number						Light intensity value from sensor or null if value is provided
           *
           *  Responses:
           *  	OK: boolean						true if the call has completed successfully, false if not.
           *  if OK is false:
           *  	errorCode: string				A code identifying the error. One of AUTH_ERROR, ERROR_MISSING_VALUE,
           *  									ERROR_INVALID_DATA, ERROR_READING_DATA
           *  	errorMessage: string			A message describing the error
           */

        // Create preamble for data
        JSONObject content = preparePreamble();

        // Fill rest of the content data

        // Create sensor data object
        JSONObject temperatureData = makeSensorObject(message);

        double temp = convertTemp(message.get_temperature());
        //System.out.println(temp);

        temperatureData.put("temp", temp);
        temperatureData.put("lux", JSONObject.NULL);

        JSONObject lightData = makeSensorObject(message);
        lightData.put("lux", message.get_lux());
        lightData.put("temp", JSONObject.NULL);

        JSONObject couchDBData = makeSensorObject(message);
        couchDBData.put("lux", message.get_lux());
        couchDBData.put("temp", temp);
        couchThread.postData(couchDBData);

        // Create the sensor data array
        JSONArray arrayData = new JSONArray();
        arrayData.put(temperatureData);
        arrayData.put(lightData);

        // Add array to content
        content.put("sensorData", arrayData);

        // Set data and its type to JSON
        StringRepresentation representation = new StringRepresentation(content.toString());
        representation.setMediaType(MediaType.APPLICATION_JSON);

        // Print representation for debugging
        //System.out.println(representation.getText());

        // Perform the POST
        Representation result = energyDataSampleClientResource.post(representation);

        // Handle the result
        handlePost(energyDataSampleClientResource, result);
    }


    /**
     * Posts fire event
     * @param sensorIdList  list of sensors reporting fire
     * @throws Exception    exception thrown when posting unsuccessful
     */
    public void postFireEvent(Set<Integer> sensorIdList) throws Exception {

        /*
           *  POST /energyInfo/event - Send an event identified by your sensors
           *  Accept content: application/json
           *  Parameters:
           *  groupId: string 					Your group number
           *  key: string							API "key" as provided per group
           *  groupName: string (optional)		An optional name for your group
           *  eventType: string					Value: "FIRE"
           *  eventMessage: string				A string describing the event
           *  sensorIdList: array [number]		An array of one or more numbers(0-2) specifying the sensors that have detected
           *  									a fire condition. NOTE: A full FIRE event will only be triggered when all three
           *  									sensors  IDs appear in the sensorIdList parameter in a single request.
           *  Responses:
           *  	OK: boolean						true if the call has completed successfully, false if not.
           *  if OK is false:
           *  	errorCode: string				A code identifying the error. One of AUTH_ERROR, ERROR_MISSING_VALUE,
           *  									ERROR_INVALID_DATA, ERROR_READING_DATA
           *  	errorMessage: string			A message describing the error
           */

        JSONObject content = preparePreamble();

        // Set the information about the fire event.
        content.put("eventType", "FIRE");
        content.put("eventMessage", "A fire event occurred!");

        // create the sensorIdList
        JSONArray sensorIdListJSON = new JSONArray();
        for (Integer sensorId : sensorIdList) {
            sensorIdListJSON.put(sensorId);
        }

        content.put("sensorIdList", sensorIdListJSON);

        // Set data and its type to JSON
        StringRepresentation representation = new StringRepresentation(content.toString());
        representation.setMediaType(MediaType.APPLICATION_JSON);

        // Print representation for debugging
        System.out.println(representation.getText());

        // Perform the POST
        Representation result = energyEventClientResource.post(representation);

        // Handle the result
        handlePost(energyEventClientResource, result);
    }

    /**
     * Returns sensor id as mapped by node id. If the mapping has not yet been
     * created for the input node id a new mapping is created.
     * @param nodeID  input node id
     * @return  sensor id associated with input node
     */
    public int getSensorId(int nodeID) {

        if (!sensorNodeMapping.containsKey(nodeID)) {
            sensorNodeMapping.put(nodeID, mappingCounter);
            mappingCounter++;
        }
        if (sensorNodeMapping.size() > NODES_NUM) {
            System.err.println("There are more nodes relaying messages than allowed!");
        }
        return sensorNodeMapping.get(nodeID);
    }

    /*
     * Handles the output of the data collection unit
     */
    private void handlePost(ClientResource cResource, Representation result) {


        if (cResource.getStatus().equals(Status.SUCCESS_OK)) {

            // handle data on success
            String jsonData;
            try {
                jsonData = result.getText();
                JSONObject jsonResponse = new JSONObject(jsonData);
                String responseOK = jsonResponse.getString("OK");
                if (responseOK.compareToIgnoreCase("true") == 0) {
                    System.out.println("Correctly read!");
                } else {
                    String errorCode = jsonResponse.getString("errorCode");
                    String errorMessage = jsonResponse.getString("errorMessage");
                    System.err.println("Error (" + errorCode + "): " + errorMessage);
                }
            } catch (IOException e) {
                e.printStackTrace();
            } catch (JSONException e) {
                e.printStackTrace();
            }

        } else {
            System.err.println("Status returned differed from 200 and was: "
                    + cResource.getStatus());
        }

    }

    /*
     * Creates JSONObject with group info
     */
    private JSONObject preparePreamble() {
        JSONObject preamble = new JSONObject();
        try {
            preamble.put("groupId", groupID);
            preamble.put("key", APIKey);
            preamble.put("groupName", groupName);
        } catch (JSONException e) {
            System.err.println("PreparePreamble Error!");
            e.printStackTrace();
        }

        return preamble;
    }

    /*
     * Returns JSON object encapsulating the sensor data for both: temperature
     * and light reading. Also timestamps the reading
     */
    private JSONObject makeSensorObject(SerialMsg message)
            throws JSONException {

        JSONObject sensorData = new JSONObject();
        sensorData.put("sensorId", getSensorId(message.get_srcid()));
        sensorData.put("nodeId", message.get_srcid());
        sensorData.put("timestamp", (new Date()).getTime());
        return sensorData;
    }


    /*
     * Returns the temperature in Kelvin given a mote temperature
     *
     */
    private double convertTemp(short moteTemperature){

        double a = 0.001010024;
        double b = 0.000242127;
        double c = 0.000000146;
        double r1 = 10000;
        double adc_fs = 1023;

        double rthr = r1*(adc_fs - moteTemperature) / moteTemperature;
        double tempTemp =  1/ (a + b * Math.log(rthr) + c * Math.pow(Math.log(rthr),3 ));
        return tempTemp - 273.15;

    }

    /*
     *
     */
    private class CouchDBThread extends Thread {

        private ArrayBlockingQueue<JSONObject> requestQueue;

        public CouchDBThread() {
            requestQueue = new ArrayBlockingQueue<JSONObject>(REQUEST_NUM);
        }

        public void postData(JSONObject obj) {
            if (requestQueue.remainingCapacity() != 0) {
                requestQueue.add(obj);
            }
        }


        public void run() {
            while (true) {
                try {
                    Thread.sleep(10000);
                    ArrayList<JSONObject> objects = new ArrayList<JSONObject>();
                    requestQueue.drainTo(objects);

                    if (!objects.isEmpty()) {
                        postDataSampleToCouch(objects);
                    }
                } catch (InterruptedException e) {
                    System.err.println("Error while draining couch queue \n" + e);
                }
            }
        }

        private void postDataSampleToCouch(ArrayList<JSONObject> msgs) {

            JSONObject toSend = new JSONObject();

            try {
                toSend.put("docs" , msgs);
            } catch (JSONException e) {
                System.err.println("Error while creating json array: \n" + e);
            }

            System.out.println(toSend.toString());

            StringRepresentation representation = new StringRepresentation(toSend.toString());
            representation.setMediaType(MediaType.APPLICATION_JSON);

            Representation result = couchDBResource.post(representation);
            try {
                System.out.println(result.getText());
            } catch (IOException e) {
                System.err.println("Error while posting to couch db \n" + e);
            }
        }

    }
}
