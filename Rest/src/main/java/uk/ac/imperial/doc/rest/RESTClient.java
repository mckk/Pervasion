package uk.ac.imperial.doc.rest;

import java.io.IOException;

import org.json.JSONException;
import org.json.JSONObject;
import org.omg.CORBA.Request;
import org.restlet.data.MediaType;
import org.restlet.data.Method;
import org.restlet.data.Status;
import org.restlet.representation.Representation;
import org.restlet.representation.StringRepresentation;
import org.restlet.resource.ClientResource;
import org.restlet.resource.ResourceException;


/**
 * REST client main class
 */
public class RESTClient 
{
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
	
	public RESTClient() {
		String energyDataURL = "http://" + dataCollectionAddr1 + ":8080/energy-data-service/energyInfo/dataSample";
		String energyEventURL = "http://" + dataCollectionAddr1 + ":8080/energy-data-service/energyInfo/event";
		
		energyDataSampleClientResource = new ClientResource(energyDataURL);
		energyEventClientResource = new ClientResource(energyEventURL);
		
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
    
    public void postDataSamples() throws ResourceException {
    	
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
    	
    	//
    	
    	try {
    		energyDataSampleClientResource.get().write(System.out);
    	}
    	catch(IOException e){
    		System.out.println("Error");
    	}
    	  
    	
    	//StringRepresentation representation = new StringRepresentation(content.toString());
    	//representation.setMediaType(MediaType.APPLICATION_ALL);
    	
    	//System.out.println(representation.getText());
    	Representation result = energyDataSampleClientResource.post(null);
    	
    	
    	if (energyDataSampleClientResource.getStatus().equals(Status.SUCCESS_OK)) {
    		
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
	    			System.out.println("ERR! " + errorCode + ": " + errorMessage);
	    		}
			} catch (IOException e) {
				e.printStackTrace();
			} catch (JSONException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
    		
		} else {
			
		}
    	
    	
    	
    }
    
    public void postEvent() {
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
    	
    	
    }
    
    
    
}