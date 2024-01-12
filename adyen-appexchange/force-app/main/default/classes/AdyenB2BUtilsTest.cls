@IsTest
private class AdyenB2BUtilsTest {
    @IsTest
    private static void retrieveAdyenAdapterTest() {
        // given - custom metadata type is visible in test scenario
        // when
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        // then
        Assert.isNotNull(adyenAdapter);
    }

    @IsTest
    private static void makePostRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentMethodsSuccessMock());
        String body = '{}';
        // when
        Test.startTest();
        HttpResponse response = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payment_Methods_Endpoint__c', body);
        Test.stopTest();
        // then
        Assert.isNotNull(response);
    }

    @IsTest
    private static void makePostRequestErrorTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.GenericErrorMock());
        String body = '{}';
        try { // when
            Test.startTest();
            AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payment_Methods_Endpoint__c', body);
            Test.stopTest();
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }
    }

    @IsTest
    private static void getApplicationInfoTest() {
        // given
        String systemIntegrator = 'test';
        // when
        Test.startTest();
        ApplicationInfo applicationInfo = AdyenB2BUtils.getApplicationInfo(systemIntegrator);
        Test.stopTest();
        // then
        Assert.areEqual(AdyenB2BConstants.EXTERNAL_PLATFORM_NAME_FOR_APP_INFO, applicationInfo.externalPlatform.name);
        Assert.areEqual(systemIntegrator, applicationInfo.externalPlatform.integrator);
        Assert.areEqual(AdyenB2BConstants.MERCHANT_APP_NAME_FOR_APP_INFO, applicationInfo.merchantApplication.name);
        Assert.areEqual(AdyenB2BConstants.MERCHANT_APP_VERSION_FOR_APP_INFO, applicationInfo.merchantApplication.version);
        Assert.areEqual(AdyenB2BConstants.ADYEN_LIBRARY_NAME_FOR_APP_INFO, applicationInfo.adyenLibrary.name);
        Assert.areEqual(AdyenB2BConstants.ADYEN_LIBRARY_VERSION_FOR_APP_INFO, applicationInfo.adyenLibrary.version);
    }

    @IsTest
    private static void getSiteCheckoutUrlTest() {
        // given - cannot simulate network id in test environment
        // when
        Test.startTest();
        String checkoutURL = AdyenB2BUtils.getSiteCheckoutUrl('/checkout');
        Test.stopTest();
        // then
        Assert.isNotNull(checkoutURL);
        Assert.isTrue(checkoutURL.contains('/checkout'));
    }
}