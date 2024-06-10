public with sharing class AdyenB2BUtils {
    public class AdyenCustomException extends Exception {}
    public static Adyen_Adapter__mdt retrieveAdyenAdapter(String adyenAdapterName) {
        return [
            SELECT Merchant_Account__c, Endpoint_Api_Version__c, Payment_Methods_Endpoint__c, Client_Key__c,
                Payments_Endpoint__c, System_Integrator_Name__c, Payments_Details_Endpoint__c, HMAC_Key__c
            FROM Adyen_Adapter__mdt
            WHERE DeveloperName = :adyenAdapterName
        ];
    }

    public static WebCart fetchCartDetails() {
        return [
            SELECT GrandTotalAmount, CurrencyIsoCode, Owner.Name, AccountId
            FROM WebCart
            WHERE OwnerId = :UserInfo.getUserId() AND Status IN ('Active', 'Checkout')
            WITH USER_MODE
        ];
    }

    public static String getSiteUrl() {
        Id networkId = Network.getNetworkId();
        if (!Test.isRunningTest() && networkId == null ) {
            throw new AdyenCustomException('Could not get site URL');
        }
        String networkLoginUrl = Test.isRunningTest() ? Url.getOrgDomainUrl().toExternalForm() + '/login' : Network.getLoginUrl(networkId);
        String networkSiteUrl = networkLoginUrl.removeEnd('/login');
        return networkSiteUrl;
    }

    public static HttpResponse makePostRequest(Adyen_Adapter__mdt adyenAdapter, String endpointFieldName, String body) {
        String compatibleBody = makeAdyenCompatible(body);
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:adyen_payment__AdyenCheckout' + buildEndpoint(adyenAdapter, endpointFieldName));
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setBody(compatibleBody);
        HttpResponse response = new Http().send(req);
        if (response.getStatusCode() != 200) {
            throw new AdyenCustomException('Adyen API returned: ' + response.getStatusCode() + ', body: ' + response.getBody());
        } else {
            return response;
        }
    }

    private static String buildEndpoint(Adyen_Adapter__mdt adyenAdapter, String endpointFieldName) {
        return adyenAdapter.Endpoint_Api_Version__c + adyenAdapter.get(endpointFieldName);
    }

    public static String makeAdyenCompatible(String input) {
        Map<String, String> mapKeyToReplace = new Map<String, String> {
                'currency_x' => 'currency',
                'number_x' => 'number',
                'group_x' => 'group'
        };
        return replaceAttributeName(input, mapKeyToReplace);
    }

    public static String makeSalesforceCompatible(String input) {
        Map<String, String> mapKeyToReplace = new Map<String, String>{
                'currency' => 'currency_x',
                'number' => 'number_x',
                'group' => 'group_x'
        };
        return replaceAttributeName(input, mapKeyToReplace);
    }

    private static String replaceAttributeName(String input, Map<String,String> fromKeyToValueMap) {
        String output = input;
        for (String key : fromKeyToValueMap.keySet()) {
            output = output.replace(key, fromKeyToValueMap.get(key));
        }
        return output;
    }

    public static Integer getAmountMultiplier(String currencyCode) {
        if (AdyenB2BConstants.THREE_DECIMAL_CURRENCIES.contains(currencyCode)) {
            return 1000;
        }
        if (AdyenB2BConstants.ZERO_DECIMAL_CURRENCIES.contains(currencyCode)) {
            return 1;
        }
        return 100;
    }

    public static Id fetchAdyenGatewayId() {
        return Test.isRunningTest() ?
            null :
            [SELECT Id FROM PaymentGateway WHERE PaymentGatewayName = :AdyenB2BConstants.DEFAULT_PAYMENT_GATEWAY_NAME].Id;
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

    public static Boolean isPaymentAccepted(PaymentsResponse.ResultCodeEnum paymentResultCode) {
        switch on paymentResultCode {
            when AUTHORISED, PENDING, RECEIVED {
                return true;
            }
            when else {
                return false;
            }
        }
    }

    public static String truncateText(String text, Integer maxLength) {
        if (String.isBlank(text) || maxLength == null || maxLength < 1) {
            return null;
        } else if (text.length() > maxLength) {
            return text.substring(0, maxLength);
        } else {
            return text;
        }
    }

    public static String safeAssignTextFieldValue(String text, Schema.DescribeFieldResult describeFieldResult) {
        return truncateText(text, describeFieldResult.getLength());
    }
}