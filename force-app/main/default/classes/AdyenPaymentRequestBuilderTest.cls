@IsTest
private class AdyenPaymentRequestBuilderTest {
    @IsTest
    static void createCardPaymentRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE);
        WebCart cart = TestDataFactory.mockCartRecord('0a61Q000000LOhYQAW', '0051Q00000eb3l5QAA', 99.99);
        // when
        Test.startTest();
        PaymentsRequest paymentsRequest = AdyenPaymentRequestBuilder.create(clientDetails, cart, adyenAdapter);
        Test.stopTest();
        // then
        assertCommonPaymentsRequestValues(paymentsRequest, cart, adyenAdapter.Merchant_Account__c);
        Assert.isNotNull(paymentsRequest.authenticationData);
        Assert.isNotNull(paymentsRequest.authenticationData.threeDSRequestData);
        Assert.areEqual('preferred', paymentsRequest.authenticationData.threeDSRequestData.nativeThreeDS);
    }

    @IsTest
    static void saveCardPaymentRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE);
        clientDetails.storePaymentMethod = true;
        WebCart cart = TestDataFactory.mockCartRecord('0a61Q000000LOhYQAW', '0051Q00000eb3l5QAA', 99.99);
        // when
        Test.startTest();
        PaymentsRequest paymentRequest = AdyenPaymentRequestBuilder.create(clientDetails, cart, adyenAdapter);
        Test.stopTest();
        // then
        assertCommonPaymentsRequestValues(paymentRequest, cart, adyenAdapter.Merchant_Account__c);
        Assert.areEqual(PaymentsRequest.ShopperInteractionEnum.Ecommerce, paymentRequest.shopperInteraction);
        Assert.areEqual(PaymentsRequest.RecurringProcessingModelEnum.CardOnFile, paymentRequest.recurringProcessingModel);
    }

    @IsTest
    static void savedCardPaymentRequest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE);
        CardDetails cardPaymentMethod = (CardDetails)clientDetails.getPaymentMethodDetails();
        cardPaymentMethod.storedPaymentMethodId = '123abc';
        clientDetails.paymentMethod = JSON.serialize(cardPaymentMethod);
        WebCart cart = TestDataFactory.mockCartRecord('0a61Q000000LOhYQAW', '0051Q00000eb3l5QAA', 99.99);
        // when
        Test.startTest();
        PaymentsRequest paymentRequest = AdyenPaymentRequestBuilder.create(clientDetails, cart, adyenAdapter);
        Test.stopTest();
        // then
        assertCommonPaymentsRequestValues(paymentRequest, cart, adyenAdapter.Merchant_Account__c);
        Assert.areEqual(PaymentsRequest.RecurringProcessingModelEnum.CardOnFile, paymentRequest.recurringProcessingModel);
        Assert.areEqual(PaymentsRequest.ShopperInteractionEnum.ContAuth, paymentRequest.shopperInteraction);
    }

    @IsTest
    static void createSepaPaymentRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails(AdyenB2BConstants.SEPA_DIRECT_DEBIT);
        WebCart cart = TestDataFactory.mockCartRecord('0a61Q000000LOhYQAW', '0051Q00000eb3l5QAA', 99.99);
        // when
        Test.startTest();
        PaymentsRequest paymentsRequest = AdyenPaymentRequestBuilder.create(clientDetails, cart, adyenAdapter);
        Test.stopTest();
        // then
        assertCommonPaymentsRequestValues(paymentsRequest, cart, adyenAdapter.Merchant_Account__c);
    }

    @IsTest
    static void createAchPaymentRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails(AdyenB2BConstants.ACH_DIRECT_DEBIT);
        WebCart cart = TestDataFactory.mockCartRecord('0a61Q000000LOhYQAW', '0051Q00000eb3l5QAA', 99.99);
        // when
        Test.startTest();
        PaymentsRequest paymentsRequest = AdyenPaymentRequestBuilder.create(clientDetails, cart, adyenAdapter);
        Test.stopTest();
        // then
        assertCommonPaymentsRequestValues(paymentsRequest, cart, adyenAdapter.Merchant_Account__c);
    }

    @IsTest
    static void nonSupportedPaymentRequestTest() {
        // given
        ClientDetails clientDetails = TestDataFactory.createClientDetails('unhandled');
        clientDetails.paymentMethodType = 'unhandled';
        try {   // when
            AdyenPaymentRequestBuilder.create(clientDetails, null, null);
            Assert.fail();
        } catch (Exception ex) {    // then
            Assert.isInstanceOfType(ex, AdyenB2BUtils.AdyenCustomException.class);
        }
    }

    private static void assertCommonPaymentsRequestValues(PaymentsRequest paymentRequest, WebCart cart, String merchantAccount) {
        Assert.areEqual(merchantAccount, paymentRequest.merchantAccount);
        Assert.areEqual(cart.Id, paymentRequest.reference);
        Assert.areEqual(cart.OwnerId, paymentRequest.shopperReference);
        Assert.areEqual(cart.CurrencyIsoCode, paymentRequest.amount.currency_x);
        Assert.isTrue(paymentRequest.returnUrl.contains('/payment-processing'));
        Long expectedValue = (cart.GrandTotalAmount * AdyenB2BUtils.getAmountMultiplier(cart.CurrencyIsoCode)).longValue();
        Assert.areEqual(expectedValue, paymentRequest.amount.value);
        Assert.areEqual('NL', paymentRequest.billingAddress.country);
        Assert.areEqual('Rotterdam', paymentRequest.billingAddress.city);
        Assert.areEqual('3012 AH', paymentRequest.billingAddress.postalCode);
        Assert.areEqual('en-US', paymentRequest.browserInfo.language);
        Assert.areEqual('*/*', paymentRequest.browserInfo.acceptHeader);
        Assert.areEqual('Web', paymentRequest.channel);
        Assert.areEqual(Url.getOrgDomainUrl().toExternalForm(), paymentRequest.origin);
    }
}