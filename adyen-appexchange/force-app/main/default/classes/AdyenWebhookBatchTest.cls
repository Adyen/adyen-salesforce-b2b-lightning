@IsTest
private class AdyenWebhookBatchTest {
    @IsTest
    static void authWebhookLogProcessingTest() {
        // given
        PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
        insert paymentAuthorization;
        PaymentGatewayLog paymentGatewayLog = createAuthLog(paymentAuthorization.GatewayRefNumber, 'true');
        insert paymentGatewayLog;
        // when
        AdyenWebhookBatch adyenWebhookBatch = new AdyenWebhookBatch();
        Test.startTest();
        Database.executeBatch(adyenWebhookBatch);
        Test.stopTest();
        // then
        paymentAuthorization = [SELECT Status, OrderPaymentSummaryId FROM PaymentAuthorization WHERE Id = :paymentAuthorization.Id];
        paymentGatewayLog = [SELECT InteractionStatus, ReferencedEntityId, OrderPaymentSummaryId FROM PaymentGatewayLog WHERE Id = :paymentGatewayLog.Id];
        Assert.areEqual('Processed', paymentAuthorization.Status);
        Assert.areEqual('Success', paymentGatewayLog.InteractionStatus);
        Assert.areEqual(paymentAuthorization.Id, paymentGatewayLog.ReferencedEntityId);
        Assert.areEqual(paymentAuthorization.OrderPaymentSummaryId, paymentGatewayLog.OrderPaymentSummaryId);
    }

    @IsTest
    static void authWebhookPayAuthNotPendingTest() {
        // given
        PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Processed');
        insert paymentAuthorization;
        PaymentGatewayLog paymentGatewayLog = createAuthLog(paymentAuthorization.GatewayRefNumber, 'true');
        insert paymentGatewayLog;
        // when
        AdyenWebhookBatch adyenWebhookBatch = new AdyenWebhookBatch();
        Test.startTest();
        Database.executeBatch(adyenWebhookBatch);
        Test.stopTest();
        // then
        paymentAuthorization = [SELECT Status FROM PaymentAuthorization WHERE Id = :paymentAuthorization.Id];
        paymentGatewayLog = [SELECT InteractionStatus FROM PaymentGatewayLog WHERE Id = :paymentGatewayLog.Id];
        Assert.areEqual('Processed', paymentAuthorization.Status);
        Assert.areEqual('Success', paymentGatewayLog.InteractionStatus);
    }

    @IsTest
    static void authWebhookNoPayAuthRelatedTest() {
        // given
        PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
        insert paymentAuthorization;
        PaymentGatewayLog paymentGatewayLog = createAuthLog('NoGoodPSPReference', 'true');
        insert paymentGatewayLog;
        // when
        AdyenWebhookBatch adyenWebhookBatch = new AdyenWebhookBatch();
        Test.startTest();
        Database.executeBatch(adyenWebhookBatch);
        Test.stopTest();
        // then
        paymentAuthorization = [SELECT Status FROM PaymentAuthorization WHERE Id = :paymentAuthorization.Id];
        paymentGatewayLog = [SELECT InteractionStatus FROM PaymentGatewayLog WHERE Id = :paymentGatewayLog.Id];
        Assert.areEqual('Pending', paymentAuthorization.Status);
        Assert.areEqual('Initiated', paymentGatewayLog.InteractionStatus);
    }

    @IsTest
    static void authWebhookLoadTest() {
        // given
        List<PaymentAuthorization> paymentAuthorizations = new List<PaymentAuthorization>();
        for (Integer i = 0; i < 200; i++) {
            PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
            paymentAuthorization.GatewayRefNumber = paymentAuthorization.GatewayRefNumber + i;
            paymentAuthorizations.add(paymentAuthorization);
        }
        insert paymentAuthorizations;
        List<PaymentAuthorization> notRelatedPaymentAuthorizations = new List<PaymentAuthorization>();
        for (Integer i = 200; i < 400; i++) {
            PaymentAuthorization paymentAuthorization = TestDataFactory.createPaymentAuthorization('Pending');
            paymentAuthorization.GatewayRefNumber = paymentAuthorization.GatewayRefNumber + i;
            notRelatedPaymentAuthorizations.add(paymentAuthorization);
        }
        insert notRelatedPaymentAuthorizations;
        List<PaymentGatewayLog> paymentGatewayLogs = new List<PaymentGatewayLog>();
        for (Integer i = 0; i < 100; i++) {
            PaymentGatewayLog paymentGatewayLog = createAuthLog(paymentAuthorizations[i].GatewayRefNumber, 'true');
            paymentGatewayLogs.add(paymentGatewayLog);
        }
        insert paymentGatewayLogs;
        List<PaymentGatewayLog> notRelatedPaymentGatewayLogs = new List<PaymentGatewayLog>();
        for (Integer i = 0; i < 100; i++) {
            PaymentGatewayLog paymentGatewayLog = createAuthLog('NotRelatedPSPReference', 'true');
            notRelatedPaymentGatewayLogs.add(paymentGatewayLog);
        }
        insert notRelatedPaymentGatewayLogs;
        // when
        AdyenWebhookBatch adyenWebhookBatch = new AdyenWebhookBatch();
        Test.startTest();
        Database.executeBatch(adyenWebhookBatch);
        Test.stopTest();
        // then
        Integer numberPAPending = [SELECT COUNT() FROM PaymentAuthorization WHERE Status = 'Pending'];
        Integer numberPAProcessed = [SELECT COUNT() FROM PaymentAuthorization WHERE Status = 'Processed'];
        Integer numberGateLogsInitiated = [SELECT COUNT() FROM PaymentGatewayLog WHERE InteractionStatus = 'Initiated'];
        Integer numberGateLogsSuccess = [SELECT COUNT() FROM PaymentGatewayLog WHERE InteractionStatus = 'Success'];
        Assert.areEqual(300, numberPAPending);
        Assert.areEqual(100, numberPAProcessed);
        Assert.areEqual(100, numberGateLogsInitiated);
        Assert.areEqual(100, numberGateLogsSuccess);
    }

    @IsTest
    static void authWebhookExceptionTest() {
        // given
        PaymentGatewayLog paymentGatewayLog = createAuthLog('pspReference', 'true');
        insert paymentGatewayLog;
        AdyenWebhookBatch adyenWebhookBatch = new AdyenWebhookBatch();
        adyenWebhookBatch.exceptions.add(new AuraHandledException('test exception'));
        adyenWebhookBatch.sendEmailToTheseAddresses.add('danilo.cardoso@adyen.com');
        adyenWebhookBatch.sendNotificationToTheseUsers.add(UserInfo.getUserId());
        // when
        Test.startTest();
        Database.executeBatch(adyenWebhookBatch);
        Test.stopTest();
        // then
        paymentGatewayLog = [SELECT InteractionStatus FROM PaymentGatewayLog WHERE Id = :paymentGatewayLog.Id];
        Assert.areEqual('Initiated', paymentGatewayLog.InteractionStatus);
    }

    private static PaymentGatewayLog createAuthLog(String pspReference, String result) {
        PaymentGatewayLog paymentGatewayLog = new PaymentGatewayLog();
        paymentGatewayLog.GatewayRefNumber = pspReference;
        paymentGatewayLog.InteractionType = 'Authorization';
        paymentGatewayLog.InteractionStatus = 'Initiated';
        paymentGatewayLog.GatewayResultCode = result;
        return paymentGatewayLog;
    }
}
