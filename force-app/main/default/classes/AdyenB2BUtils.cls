public with sharing class AdyenB2BUtils {
    public class AdyenCustomException extends Exception {}
    public static Adyen_Adapter__mdt retrieveAdyenAdapter(String adyenAdapterName) {
        List<Adyen_Adapter__mdt> adyenAdapters = [
            SELECT Merchant_Account__c, Endpoint_Api_Version__c, Payment_Methods_Endpoint__c, Client_Key__c,
                Payments_Endpoint__c, System_Integrator_Name__c, Payments_Details_Endpoint__c, HMAC_Key__c,
                Package_Namespace__c, Named_Credential__c
            FROM Adyen_Adapter__mdt
            WHERE DeveloperName = :adyenAdapterName
        ];
        if (adyenAdapters.isEmpty()) {
            throw new AdyenCustomException('No Adyen adapter found with this name: ' + adyenAdapterName);
        }
        return adyenAdapters[0];
    }

    public static Adyen_Adapter__mdt retrieveAdyenAdapterByMerchantAcct(String merchantAccountName) {
        List<Adyen_Adapter__mdt> adyenAdapters = [
            SELECT Merchant_Account__c, Endpoint_Api_Version__c, Payment_Methods_Endpoint__c, Client_Key__c,
                Payments_Endpoint__c, System_Integrator_Name__c, Payments_Details_Endpoint__c, HMAC_Key__c,
                Package_Namespace__c, Named_Credential__c
            FROM Adyen_Adapter__mdt
            WHERE Merchant_Account__c = :merchantAccountName
        ];
        if (adyenAdapters.isEmpty()) {
            throw new AdyenCustomException('No Adyen adapter found for this merchant account: ' + merchantAccountName);
        }
        return adyenAdapters[0];
    }

    public static WebCart fetchCartDetails() {
        List<WebCart> webCarts = [
            SELECT GrandTotalAmount, CurrencyIsoCode, Owner.Name, AccountId
            FROM WebCart
            WHERE OwnerId = :UserInfo.getUserId() AND Status IN ('Active', 'Checkout')
            WITH USER_MODE
        ];
        if (webCarts.isEmpty()) {
            throw new AdyenCustomException('No active or in checkout cart found for this user id: ' + UserInfo.getUserId());
        }
        return webCarts[0];
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
        req.setEndpoint(buildEndpoint(adyenAdapter, endpointFieldName));
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
        String namedCredential = adyenAdapter.Named_Credential__c;
        String namespace = String.isNotBlank(adyenAdapter.Package_Namespace__c) ? adyenAdapter.Package_Namespace__c + '__' : '';
        String endpointUrl = 'callout:' + namespace + namedCredential;
        
        String apiVersion = adyenAdapter.Endpoint_Api_Version__c;
        String endpointPath = (String) adyenAdapter.get(endpointFieldName);
        
        return endpointUrl + apiVersion + endpointPath;
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