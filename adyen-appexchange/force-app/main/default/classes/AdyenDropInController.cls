/**
 * Created by daniloc on 16/11/2023.
 */

public with sharing class AdyenDropInController {
    @AuraEnabled(Cacheable=true)
    public static String fetchPaymentMethods(String adyenAdapterName) {
        Adyen_Adapter__mdt adyenAdapter = AdyenUtils.retrieveAdyenAdapter(adyenAdapterName);
        PaymentMethodsRequest paymentMethodsRequest = new PaymentMethodsRequest();
        paymentMethodsRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        String paymentMethodsEndpoint = adyenAdapter.Endpoint_Api_Version__c + adyenAdapter.Payment_Methods_Endpoint__c;

        HttpResponse result = AdyenUtils.makePostRequest(paymentMethodsEndpoint, JSON.serialize(paymentMethodsRequest));

        if (result.getStatusCode() != 200) {
            throw new AuraHandledException('API returned: ' + result.getBody());
        } else {
            PaymentMethodsResponse paymentMethodsResponse = (PaymentMethodsResponse)JSON.deserialize(result.getBody(), PaymentMethodsResponse.class);
            paymentMethodsResponse.paymentMethods = AdyenUtils.filterOnlyCardPaymentMethod(paymentMethodsResponse.paymentMethods);
            return JSON.serialize(paymentMethodsResponse);
        }
    }
}