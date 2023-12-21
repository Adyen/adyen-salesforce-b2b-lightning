public with sharing class AdyenB2BUtils {
    public static Adyen_Adapter__mdt retrieveAdyenAdapter(String adyenAdapterName) {
        try {
            return [
                SELECT Merchant_Account__c, Endpoint_Api_Version__c, Payment_Methods_Endpoint__c, Client_Key__c, Payments_Endpoint__c, System_Integrator_Name__c
                FROM Adyen_Adapter__mdt
                WHERE DeveloperName = :adyenAdapterName
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception ex) {
            throw new AuraHandledException('Could not find adyen adapter with name: ' + adyenAdapterName + '. Error: ' + ex.getMessage());
        }
    }

    public static HttpResponse makePostRequest(Adyen_Adapter__mdt adyenAdapter, String endpointFieldName, String body) {
        String compatibleBody = makeAdyenCompatible(body);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AdyenCheckout' + buildEndpoint(adyenAdapter, endpointFieldName));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(compatibleBody);
        HttpResponse response = new Http().send(req);
        if (response.getStatusCode() != 200) {
            throw new AuraHandledException('API returned: ' + response.getStatusCode());
        } else {
            return response;
        }
    }

    private static String buildEndpoint(Adyen_Adapter__mdt adyenAdapter, String endpointFieldName) {
        try {
            return adyenAdapter.Endpoint_Api_Version__c + adyenAdapter.get(endpointFieldName);
        } catch (Exception ex) {
            throw new AuraHandledException('Could not build endpoint with field: ' + endpointFieldName + '. Error: ' + ex.getMessage());
        }

    }

    private static String makeAdyenCompatible(String input) {
        Map<String, String> mapKeyToReplace = new Map<String, String> {
                'currency_x' => 'currency',
                'number_x' => 'number',
                'group_x' => 'group'
        };
        String output = input;
        for (String key : mapKeyToReplace.keySet()) {
            output = output.replace(key, mapKeyToReplace.get(key));
        }
        return output;
    }

    public static Id fetchAdyenGatewayId() {
        return [SELECT Id FROM PaymentGateway WHERE PaymentGatewayName = :AdyenB2BConstants.DEFAULT_PAYMENT_GATEWAY_NAME].Id;
    }

    public static String makeSalesforceCompatible(String adyenPaymentMethodType) {
        String salesForcePayMethodType = AdyenB2BConstants.ADYEN_PAYMENT_TYPE_TO_SF_TYPE.get(adyenPaymentMethodType);
        return String.isNotBlank(salesForcePayMethodType) ? salesForcePayMethodType : adyenPaymentMethodType;
    }

    public static ApplicationInfo getApplicationInfo(String systemIntegratorName) {
        ApplicationInfo applicationInfo = new ApplicationInfo();

        ExternalPlatform externalPlatform = new ExternalPlatform();
        externalPlatform.name = AdyenB2BConstants.EXTERNAL_PLATFORM_NAME_FOR_APP_INFO;
        externalPlatform.integrator = systemIntegratorName;
        applicationInfo.externalPlatform = externalPlatform;

        CommonField merchantApplication = new CommonField();
        merchantApplication.name = AdyenB2BConstants.MERCHANT_APP_NAME_FOR_APP_INFO;
        merchantApplication.version = AdyenB2BConstants.MERCHANT_APP_VERSION_FOR_APP_INFO;
        applicationInfo.merchantApplication = merchantApplication;

        CommonField adyenLibrary = new CommonField();
        adyenLibrary.name = AdyenB2BConstants.ADYEN_LIBRARY_NAME_FOR_APP_INFO;
        adyenLibrary.version = AdyenB2BConstants.ADYEN_LIBRARY_VERSION_FOR_APP_INFO;
        applicationInfo.adyenLibrary = adyenLibrary;

        return applicationInfo;
    }
}