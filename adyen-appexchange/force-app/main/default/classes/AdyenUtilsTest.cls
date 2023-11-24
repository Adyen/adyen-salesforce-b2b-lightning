/**
 * Created by daniloc on 24/11/2023.
 */
@IsTest
private class AdyenUtilsTest {
    @IsTest
    private static void retrieveAdyenAdapterTest() {
        // given - custom metadata type is visible in test scenario
        // when
        Adyen_Adapter__mdt adyenAdapter = AdyenUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        // then
        Assert.isNotNull(adyenAdapter);
    }

    @IsTest
    private static void makePostRequestTest() {
        // given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentMethodsSuccessMock());
        String endpoint = '/paymentMethods';
        String body = '{}';
        // when
        Test.startTest();
        HttpResponse response = AdyenUtils.makePostRequest(endpoint, body);
        Test.stopTest();
        // then
        Assert.isNotNull(response);
    }

    @IsTest
    private static void getPaymentMethodTest() {
        // given - multiple payment methods
        List<PaymentMethod> paymentMethods = TestDataFactory.getMultiplePaymentMethods();
        // when
        PaymentMethod paymentMethod = AdyenUtils.getPaymentMethod(paymentMethods, AdyenConstants.CARD_PAYMENT_METHOD_TYPE);
        // then
        Assert.areEqual(AdyenConstants.CARD_PAYMENT_METHOD_TYPE, paymentMethod.type);

        // given - empty list
        List<PaymentMethod> emptyPaymentMethods = new List<PaymentMethod>();
        // when
        paymentMethod = AdyenUtils.getPaymentMethod(emptyPaymentMethods, AdyenConstants.CARD_PAYMENT_METHOD_TYPE);
        // then
        Assert.isNull(paymentMethod);
    }

    @IsTest
    private static void filterOnlyCardPaymentMethodTest() {
        // given - response with multiple payment methods
        PaymentMethodsResponse paymentMethodsResponse = PaymentMethodsResponse.getExample();
        paymentMethodsResponse.paymentMethods = TestDataFactory.getMultiplePaymentMethods();
        // when
        List<PaymentMethod> cardPaymentMethod = AdyenUtils.filterOnlyCardPaymentMethod(paymentMethodsResponse.paymentMethods);
        // then
        Assert.areEqual(1, cardPaymentMethod.size());
        Assert.areEqual(AdyenConstants.CARD_PAYMENT_METHOD_TYPE, cardPaymentMethod[0].type);

        // given - response without card payment method
        paymentMethodsResponse.paymentMethods = removeCardPaymentMethod(TestDataFactory.getMultiplePaymentMethods());
        try { // when
            List<PaymentMethod> noCardPaymentMethods = AdyenUtils.filterOnlyCardPaymentMethod(paymentMethodsResponse.paymentMethods);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }
    }

    private static List<PaymentMethod> removeCardPaymentMethod(List<PaymentMethod> paymentMethods) {
        for (Integer i = paymentMethods.size(); i > 0;) {
            if (paymentMethods[--i].type.equals(AdyenConstants.CARD_PAYMENT_METHOD_TYPE)) {
                paymentMethods.remove(i);
            }
        }
        return paymentMethods;
    }
}