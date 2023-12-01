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
}