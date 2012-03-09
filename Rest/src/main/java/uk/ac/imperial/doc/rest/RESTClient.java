package uk.ac.imperial.doc.rest;

import java.io.IOException;
import java.util.HashMap;
import java.util.Timer;
import java.util.concurrent.ConcurrentHashMap;

import com.sun.org.apache.xpath.internal.operations.Bool;
import net.tinyos.message.Message;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import org.restlet.data.Form;
import org.restlet.data.MediaType;
import org.restlet.data.Preference;
import org.restlet.data.Status;
import org.restlet.representation.Representation;
import org.restlet.representation.StringRepresentation;
import org.restlet.resource.ClientResource;


/**
 * REST client main class
 */
public class RESTClient {
    // The data collection IP addresses.
    static String dataCollectionAddr1 = "146.169.37.100";
    static String dataCollectionAddr2 = "146.169.37.101";
    static String dataCollectionAddr3 = "146.169.37.102";
    static String dataCollectionAddr4 = "146.169.37.103";

    static String groupID = "9";
    static String APIKey = "fRrefHtp";
    static String groupName = "Pervasion";

    private ClientResource energyDataSampleClientResource;
    private ClientResource energyEventClientResource;

    private Timer fireResetTimer;

    private HashMap<Integer, Integer> sensorNodeMapping;
    private int mappingCounter = 0;

    private ConcurrentHashMap<Integer, Boolean> fireMap;

    public RESTClient() {
        String energyDataURL = "http://" + dataCollectionAddr1 + ":8080/energy-data-service/energyInfo/dataSample";
        String energyEventURL = "http://" + dataCollectionAddr1 + ":8080/energy-data-service/energyInfo/event";

        energyDataSampleClientResource = new ClientResource(energyDataURL);
        energyEventClientResource = new ClientResource(energyEventURL);

        // set the accept header to application/json
        energyDataSampleClientResource.getClientInfo().getAcceptedMediaTypes().add(new Preference<MediaType>(MediaType.APPLICATION_JSON));
        energyEventClientResource.getClientInfo().getAcceptedMediaTypes().add(new Preference<MediaType>(MediaType.APPLICATION_JSON));

        sensorNodeMapping = new HashMap<Integer, Integer>(3);
        fireMap = new ConcurrentHashMap<Integer, Boolean>(3);

        fireResetTimer = new Timer();
    }

    public static void main(String args[]) throws Exception {

        RESTClient client = new RESTClient();

        SerialMsg message = new SerialMsg();
        message.set_srcid(35);
        message.set_lux((short) 59);
        message.set_temperature((short) 200);


        if (message.get_fire() != 0) {
            client.postEvent(message);
        } else {
            client.postDataSamples(message);
        }

        client.postDataSamples(message);

    }

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

    private JSONObject makeSensorObject(SerialMsg message, boolean isTempPacket) throws JSONException, Exception {

        JSONObject sensorData = new JSONObject();
        sensorData.put("sensorId", getSensorId(message.get_srcid()));
        sensorData.put("nodeId", message.get_srcid());
        sensorData.put("timestamp", 1000);
        if (isTempPacket) {
            sensorData.put("temp", message.get_temperature());
            sensorData.put("lux", JSONObject.NULL);
        } else {
            sensorData.put("lux", message.get_lux());
            sensorData.put("temp", JSONObject.NULL);
        }
        return sensorData;
    }

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
        JSONObject temperatureData = makeSensorObject(message, true);
        //JSONObject lightData = makeSensorObject(message, false);

        // Create the sensor data array
        JSONArray arrayData = new JSONArray();
        arrayData.put(temperatureData);
        //arrayData.put(lightData);

        // Add array to content
        content.put("sensorData", arrayData);

        // Set data and its type to JSON
        StringRepresentation representation = new StringRepresentation(content.toString());
        representation.setMediaType(MediaType.APPLICATION_JSON);

        System.out.println(representation.getText());

        // Perform the POST
        Representation result = energyDataSampleClientResource.post(representation);

        // If success
        handlePost(energyDataSampleClientResource, result);

    }


    public void postEvent(SerialMsg message) {
        fireResetTimer.cancel();
        fireResetTimer.schedule(new FireTask(this), 30000);
    }


    public void handlePost(ClientResource cResource, Representation result) throws Exception {


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
                    throw new Exception("Error (" + errorCode + "): " + errorMessage);
                }
            } catch (IOException e) {
                e.printStackTrace();
            } catch (JSONException e) {
                e.printStackTrace();
            }

        } else {

        }

    }

    public int getSensorId(int nodeID) throws Exception {

        if (!sensorNodeMapping.containsKey(nodeID)) {
            sensorNodeMapping.put(nodeID, mappingCounter);
            mappingCounter++;
        }
        if (sensorNodeMapping.size() > 2) {
            throw new Exception("There are more nodes relaying messages than allowed!");
        }
        return sensorNodeMapping.get(nodeID);
    }

    public void resetFireMap() {
        for (Integer key : fireMap.keySet()) {
            fireMap.put(key, false);
        }
    }

    public void sendFireEvent() throws Exception {

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
        JSONArray sensorIdList = new JSONArray();
        for (Integer key : fireMap.keySet()) {
            if (fireMap.get(key)) {
               sensorIdList.put(key);
            }
        }
        content.put("sensorIdList", sensorIdList);

        // Set data and its type to JSON
        StringRepresentation representation = new StringRepresentation(content.toString());
        representation.setMediaType(MediaType.APPLICATION_JSON);

        System.out.println(representation.getText());

        // Perform the POST
        Representation result = energyEventClientResource.post(representation);

        handlePost(energyEventClientResource, result);
    }

}
