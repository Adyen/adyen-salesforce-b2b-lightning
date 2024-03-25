@IsTest
private class AdyenAsyncAdapterTest {
    @IsTest
    static void processRequestTest() {
        // given a post auth request
        Double price = 19.99;
        CommercePayments.PostAuthorizationRequest postAuthRequest = new CommercePayments.PostAuthorizationRequest(price);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(postAuthRequest, CommercePayments.RequestType.PostAuth);
        AdyenAsyncAdapter adapter = new AdyenAsyncAdapter();
        // when
        CommercePayments.GatewayResponse postAuthResponse = (CommercePayments.GatewayResponse)adapter.processRequest(context);
        // then
        Assert.isTrue(postAuthResponse.toString().contains('success'));
    }

    @IsTest
    static void processNotificationTest() {
        AdyenAsyncAdapter adapter = new AdyenAsyncAdapter();
        Assert.isNull(adapter.processNotification(null));
    }
}