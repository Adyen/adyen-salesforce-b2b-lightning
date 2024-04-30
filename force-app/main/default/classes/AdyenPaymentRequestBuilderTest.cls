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
    static void nonSupportedPaymentRequestTest() {
        // given
        ClientDetails clientDetails = TestDataFactory.createClientDetails('unhandled');
        clientDetails.paymentMethodType = 'unhandled';
        try {   // when
            PaymentsRequest paymentsRequest = AdyenPaymentRequestBuilder.create(clientDetails, null, null);
            Assert.fail();
        } catch (Exception ex) {    // then
            Assert.isInstanceOfType(ex, AdyenB2BUtils.AdyenCustomException.class);
        }
    }

    private static void assertCommonPaymentsRequestValues(PaymentsRequest paymentsRequest, WebCart cart, String merchantAccount) {
        Assert.areEqual(merchantAccount, paymentsRequest.merchantAccount);
        Assert.areEqual(cart.Id, paymentsRequest.reference);
        Assert.areEqual(cart.OwnerId, paymentsRequest.shopperReference);
        Assert.areEqual(cart.CurrencyIsoCode, paymentsRequest.amount.currency_x);
        Assert.isTrue(paymentsRequest.returnUrl.contains('/payment-processing'));
        Long expectedValue = (cart.GrandTotalAmount * AdyenB2BUtils.getAmountMultiplier(cart.CurrencyIsoCode)).longValue();
        Assert.areEqual(expectedValue, paymentsRequest.amount.value);
        Assert.areEqual('NL', paymentsRequest.billingAddress.country);
        Assert.areEqual('Rotterdam', paymentsRequest.billingAddress.city);
        Assert.areEqual('3012 AH', paymentsRequest.billingAddress.postalCode);
        Assert.areEqual('en-US', paymentsRequest.browserInfo.language);
        Assert.areEqual('*/*', paymentsRequest.browserInfo.acceptHeader);
        Assert.areEqual('Web', paymentsRequest.channel);
        Assert.areEqual(Url.getOrgDomainUrl().toExternalForm(), paymentsRequest.origin);
    }
}