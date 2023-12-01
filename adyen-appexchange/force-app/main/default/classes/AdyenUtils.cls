/**
 * Created by daniloc on 23/11/2023.
 */

public with sharing class AdyenUtils {
    public static Adyen_Adapter__mdt retrieveAdyenAdapter(String adyenAdapterName) {
        try {
            return [
                SELECT Merchant_Account__c, Endpoint_Api_Version__c, Payment_Methods_Endpoint__c
                FROM Adyen_Adapter__mdt
                WHERE DeveloperName = :adyenAdapterName
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception ex) {
            throw new AuraHandledException('Could not find adyen adapter with name: ' + adyenAdapterName + '. Error: ' + ex.getMessage());
        }
    }

    public static HttpResponse makePostRequest(String endpoint, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AdyenCheckout' + endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(body);
        return new Http().send(req);
    }
}