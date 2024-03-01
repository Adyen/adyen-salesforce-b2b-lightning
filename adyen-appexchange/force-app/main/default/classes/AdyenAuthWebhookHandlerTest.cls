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

    @IsTest(SeeAllData=true)
    static void successfulNotificationWithPayAuthTest() {
        // given payment authorization pending
        Account acct = new Account(Name = 'Test');
        insert acct;
        Order testOrder = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 9.99, 0.99);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(testOrder.Id);

        PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
        paymentAuthorization.OrderPaymentSummaryId = orderPaymentSummary.Id;
        insert paymentAuthorization;
        String authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, paymentAuthorization.GatewayRefNumber, '0a61Q000000LMuaQAG', true);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(authWebhook);
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.areEqual('[accepted]', response);
        Assert.isTrue(AdyenB2BConstants.PaymentAuthorizationStatus.PROCESSED.name().equalsIgnoreCase([SELECT Status FROM PaymentAuthorization WHERE Id = :paymentAuthorization.Id].Status));
        Assert.areEqual(1, [SELECT Id FROM PaymentGatewayLog WHERE InteractionStatus = :AdyenB2BConstants.PaymentGatewayLogStatus.SUCCESS.name() AND ReferencedEntityId = :paymentAuthorization.Id].size());

        // given payment authorization already processed
        // when
        response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.isTrue(response.containsIgnoreCase('not pending'));
        Assert.areEqual(1, [SELECT Id FROM PaymentGatewayLog WHERE InteractionStatus = :AdyenB2BConstants.PaymentGatewayLogStatus.NOOP.name() AND ReferencedEntityId = :paymentAuthorization.Id].size());
    }

    @IsTest(SeeAllData=true)
    static void unsuccessfulNotificationWithPayAuthTest() {
        // given payment authorization pending
        Account acct = new Account(Name = 'Test 2');
        insert acct;
        Order testOrder = TestDataFactory.insertOrderAndRelatedRecords(acct.Id, 9.99, 0.99);
        OrderPaymentSummary orderPaymentSummary = TestDataFactory.createOrderSummaryRecords(testOrder.Id);
        PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
        paymentAuthorization.OrderPaymentSummaryId = orderPaymentSummary.Id;
        insert paymentAuthorization;
        String authWebhook = TestDataFactory.mockWebhookRequest(AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE, paymentAuthorization.GatewayRefNumber, '0a61Q000000LMuaQAG', false);
        RestRequest req = createRestRequest();
        req.requestBody = Blob.valueOf(authWebhook);
        RestContext.request = req;
        // when
        String response = AdyenAuthWebhookHandler.doPost();
        // then
        Assert.isNotNull(response);
        Assert.areEqual('[accepted]', response);
        Assert.isTrue(AdyenB2BConstants.PaymentAuthorizationStatus.FAILED.name().equalsIgnoreCase([SELECT Status FROM PaymentAuthorization WHERE Id = :paymentAuthorization.Id].Status));
        Assert.areEqual(1, [SELECT Id FROM PaymentGatewayLog WHERE InteractionStatus = :AdyenB2BConstants.PaymentGatewayLogStatus.SUCCESS.name() AND ReferencedEntityId = :paymentAuthorization.Id].size());
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
        Assert.isTrue(response.containsIgnoreCase('no cart found'));
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