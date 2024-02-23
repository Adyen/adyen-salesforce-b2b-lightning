@IsTest
private class AdyenAuthWebhookHandlerTest {
    @IsTest
    static void notValidNotificationTest() {
        // given wrong type of notification
        String notAuthWebhook = TestDataFactory.mockWebhookRequest('CAPTURE', null, null, true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(notAuthWebhook);
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('unsupported'));

        // given invalid pspReference
        String authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, '', '0a61Q000000LMuaQAG', true);
        req.requestBody = Blob.valueOf(authWebhook);
        // when
        response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('unsupported'));

        // given wrong id string
        authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, 'QFQTPCQ8HXSKGK82', 'notAndId', true);
        req.requestBody = Blob.valueOf(authWebhook);
        // when
        response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('unsupported'));
    }

    @IsTest
    static void successfulNotificationWithPayAuthTest() {
        // given payment authorization pending
        PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
        insert paymentAuthorization;
        String authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, 'QFQTPCQ8HXSKGK82', '0a61Q000000LMuaQAG', true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(authWebhook);
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.areEqual('[accepted]', response);
        Assert.areEqual('Processed', [SELECT Status FROM PaymentAuthorization LIMIT 1].Status);
        Assert.areEqual(1, [SELECT Id FROM PaymentGatewayLog WHERE InteractionStatus = 'Success' AND ReferencedEntityId = :paymentAuthorization.Id].size());

        // given payment authorization already processed
        // when
        response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('not pending'));
        Assert.areEqual(1, [SELECT Id FROM PaymentGatewayLog WHERE InteractionStatus = 'NoOp' AND ReferencedEntityId = :paymentAuthorization.Id].size());
    }

    @IsTest
    static void unsuccessfulNotificationWithPayAuthTest() {
        // given payment authorization pending
        PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
        insert paymentAuthorization;
        String authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, 'QFQTPCQ8HXSKGK82', '0a61Q000000LMuaQAG', false);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(authWebhook);
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.areEqual('[accepted]', response);
        Assert.areEqual('Failed', [SELECT Status FROM PaymentAuthorization LIMIT 1].Status);
        Assert.areEqual(1, [SELECT Id FROM PaymentGatewayLog WHERE InteractionStatus = 'Success' AND ReferencedEntityId = :paymentAuthorization.Id].size());
    }

    @IsTest(SeeAllData=true)
    static void notificationWithPayAuthMissingTest() {
        // given that there is a web cart as per the merchant reference
        Decimal unitPrice = 10.99;
        Decimal quantity = 1;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
        String authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, 'QFQTPCQ8HXSKGK82', webCart.Id, true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(authWebhook);
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('later'));
    }

    @IsTest
    static void notificationWithPayAuthMissingNoCartTest() {
        // given no web cart found for that merchant reference
        String authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, 'QFQTPCQ8HXSKGK82', '0a61Q000000LMuaQAY', true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(authWebhook);
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('no payment found'));
        Assert.isTrue([SELECT Id FROM PaymentGatewayLog].isEmpty());
    }

    @IsTest
    static void doPostExceptionTest() {
        // given
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf('null');
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('exception'));
    }

    private static RestRequest createRestRequest() {
        RestRequest req = new RestRequest();
        req.requestURI = '/services/apexrest/authWebhook/v1/';
        req.httpMethod = 'POST';
        return req;
    }
}