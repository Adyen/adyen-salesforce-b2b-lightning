@IsTest
private class AdyenB2BUtilsTest {
    @IsTest
    static void retrieveAdyenAdapterTest() {
        // given - custom metadata type is visible in test scenario
        // when
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        // then
        Assert.isNotNull(adyenAdapter);
    }

    @IsTest
    static void retrieveAdyenAdapterMissingTest() {
        // given
        String missingAdapterName = 'not there';
        // when
        try {
            AdyenB2BUtils.retrieveAdyenAdapter(missingAdapterName);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AdyenB2BUtils.AdyenCustomException.class);
        }
    }

    @IsTest
    static void retrieveAdyenAdapterByMerchantAcctTest() {
        // given
        String merchantAccountName = [SELECT Merchant_Account__c FROM Adyen_Adapter__mdt LIMIT 1].Merchant_Account__c;
        // when
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapterByMerchantAcct(merchantAccountName);
        // then
        Assert.isNotNull(adyenAdapter);
        Assert.areEqual(merchantAccountName, adyenAdapter.Merchant_Account__c);
    }

    @IsTest
    static void retrieveAdyenAdapterByMerchantAcctMissingTest() {
        // given
        String wrongMerchantAcctName = 'John Doe';
        // when
        try {
            AdyenB2BUtils.retrieveAdyenAdapterByMerchantAcct(wrongMerchantAcctName);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AdyenB2BUtils.AdyenCustomException.class);
        }
    }

    @IsTest
    static void makePostRequestTest() {
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
    static void makePostRequestErrorTest() {
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
            Assert.isInstanceOfType(ex, AdyenB2BUtils.AdyenCustomException.class);
        }
    }

    @IsTest
    static void getApplicationInfoTest() {
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
    static void getSiteUrlTest() {
        // given - cannot simulate network id in test environment
        // when
        Test.startTest();
        String checkoutURL = AdyenB2BUtils.getSiteUrl();
        Test.stopTest();
        // then
        Assert.isNotNull(checkoutURL);
        Assert.isTrue(checkoutURL.contains('.com'));
    }

    @IsTest(SeeAllData=true)
    static void fetchCartDetailsTest() {
        // given
        User buyerUser = TestDataFactory.setUpWebStoreAndBuyerUser();
        Id webStoreId = TestDataFactory.findWebStoreIdByUserId(buyerUser.Id);
        // when
        WebCart cart;
        System.runAs(buyerUser) {
            WebCart webCart = TestDataFactory.createCartWithOneItem(webStoreId, 1);
            webCart.Status = 'Checkout';
            update webCart;
            Test.startTest();
            cart = AdyenB2BUtils.fetchCartDetails();
            Test.stopTest();
        }
        // then
        Assert.isNotNull(cart);
        Assert.areEqual(TestDataFactory.TEST_UNIT_PRICE, cart.GrandTotalAmount);
    }

    @IsTest
    static void fetchCartDetailsMissingTest() {
        // given - no web store context available
        AdyenB2BUtils.webStoreTestContext = new Map<String,String>();
        // when
        try {
            AdyenB2BUtils.fetchCartDetails();
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AdyenB2BUtils.AdyenCustomException.class);
        }
        // given - no cart available
        AdyenB2BUtils.webStoreTestContext.put('webstoreId', '0ZEal000001m47BGAQ');
        // when
        try {
            AdyenB2BUtils.fetchCartDetails();
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AdyenB2BUtils.AdyenCustomException.class);
        }
    }

    @IsTest
    static void isPaymentAcceptedTest() {
        // given authorised
        PaymentsResponse.ResultCodeEnum paymentResultCode = PaymentsResponse.ResultCodeEnum.AUTHORISED;
        // when
        Boolean paymentSuccessful = AdyenB2BUtils.isPaymentAccepted(paymentResultCode);
        // then
        Assert.isTrue(paymentSuccessful);

        // given pending
        paymentResultCode = PaymentsResponse.ResultCodeEnum.PENDING;
        // when
        paymentSuccessful = AdyenB2BUtils.isPaymentAccepted(paymentResultCode);
        // then
        Assert.isTrue(paymentSuccessful);

        // given received
        paymentResultCode = PaymentsResponse.ResultCodeEnum.RECEIVED;
        // when
        paymentSuccessful = AdyenB2BUtils.isPaymentAccepted(paymentResultCode);
        // then
        Assert.isTrue(paymentSuccessful);

        // given other value
        paymentResultCode = PaymentsResponse.ResultCodeEnum.CANCELLED;
        // when
        paymentSuccessful = AdyenB2BUtils.isPaymentAccepted(paymentResultCode);
        // then
        Assert.isFalse(paymentSuccessful);
    }

    @IsTest
    static void safeAssignTextFieldValueTest() {
        // given
        String text = 'sample';
        // when
        String safeText = AdyenB2BUtils.safeAssignTextFieldValue(text, LogEntry__c.Message__c.getDescribe());
        // then
        Assert.areEqual(text, safeText);

        // given a very long text
        Integer messageFieldSize = LogEntry__c.Message__c.getDescribe().getLength();
        String longText = 'a very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long very long text';
        // when
        safeText = AdyenB2BUtils.safeAssignTextFieldValue(longText, LogEntry__c.Message__c.getDescribe());
        // then
        Assert.areNotEqual(longText, safeText);
        Assert.areEqual(messageFieldSize, safeText.length());
    }

    @IsTest
    static void getAmountMultiplierTest() {
        // given 3 decimal places currency
        String currencyCode = 'JOD';
        // when
        Integer multiplier = AdyenB2BUtils.getAmountMultiplier(currencyCode);
        // then
        Assert.areEqual(1000, multiplier);

        // given 0 decimal place currency
        currencyCode = 'JPY';
        // when
        multiplier = AdyenB2BUtils.getAmountMultiplier(currencyCode);
        // then
        Assert.areEqual(1, multiplier);

        // given 0 decimal place currency
        currencyCode = 'USD';
        // when
        multiplier = AdyenB2BUtils.getAmountMultiplier(currencyCode);
        // then
        Assert.areEqual(100, multiplier);
    }
}