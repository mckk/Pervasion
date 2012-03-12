package uk.ac.imperial.doc.rest;

import org.junit.Test;

public class FireManagerTest {

    private RESTClient client = new RESTClient();
    private FireManager fireManager = new FireManager(client);

    @Test
    public void testNotifications() throws Exception {
        fireManager.notifyAboutFire(0);
        Thread.sleep(500);

        fireManager.notifyAboutFire(1);
        Thread.sleep(3000);

        System.out.println("Second notify");
        fireManager.notifyAboutFire(0);
        fireManager.notifyAboutFire(2);
        Thread.sleep(10000);

    }
}
