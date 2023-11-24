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

    public static List<PaymentMethod> filterOnlyCardPaymentMethod(List<PaymentMethod> paymentMethods) {
        PaymentMethod cardsPaymentMethod = getPaymentMethod(paymentMethods, AdyenConstants.CARD_PAYMENT_METHOD_TYPE);
        if (cardsPaymentMethod == null) {
            throw new AuraHandledException('No card payment method type found');
        } else {
            return new List<PaymentMethod>{cardsPaymentMethod};
        }
    }

    public static PaymentMethod getPaymentMethod(List<PaymentMethod> paymentMethods, String type) {
        if (paymentMethods == null || String.isBlank(type)) {
            return null;
        }
        for (PaymentMethod paymentMethod : paymentMethods) {
            if (paymentMethod.type.equalsIgnoreCase(type)) {
                return paymentMethod;
            }
        }
        return null;
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