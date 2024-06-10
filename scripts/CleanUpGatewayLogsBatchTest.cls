@IsTest
private class CleanUpGatewayLogsBatchTest {
    @IsTest
    static void cleanUpGatewayLogsTest() {
        // given
        PaymentGatewayLog logForFailedPayment = createAuthLog('PspRef', 'false');
        insert logForFailedPayment;
        Test.setCreatedDate(logForFailedPayment.Id, Datetime.now().addDays(-31));

        PaymentGatewayLog logForSuccessPayment = createAuthLog('PspRef2', 'true');
        insert logForSuccessPayment;
        Test.setCreatedDate(logForSuccessPayment.Id, Datetime.now().addDays(-31));

        PaymentGatewayLog falseLogWithRelatedPA = createAuthLog('QFQTPCQ8HXSKGK82', 'false');
        insert falseLogWithRelatedPA;
        Test.setCreatedDate(falseLogWithRelatedPA.Id, Datetime.now().addDays(-31));
        PaymentAuthorization paymentAuthorization = new PaymentAuthorization();
        paymentAuthorization.GatewayRefNumber = 'QFQTPCQ8HXSKGK82';
        paymentAuthorization.Amount = 10.93;
        paymentAuthorization.ProcessingMode = 'External';
        paymentAuthorization.Status = 'Failed';
        insert paymentAuthorization;

        PaymentGatewayLog failedRecentLog = createAuthLog('PspRef4', 'false');
        insert failedRecentLog;

        // when
        CleanUpGatewayLogsBatch cleanUpGatewayLogsBatch = new CleanUpGatewayLogsBatch();
        Test.startTest();
        Database.executeBatch(cleanUpGatewayLogsBatch);
        Test.stopTest();

        // then
        List<PaymentGatewayLog> paymentGatewayLogs = [SELECT Id FROM PaymentGatewayLog];
        Assert.areEqual(3, paymentGatewayLogs.size());
    }

    @IsTest
    static void loadTest() {
        // given
        Integer numberOfLogsToBeDeleted = 200;
        Integer totalNumberOfLogs = 9000;
        List<PaymentGatewayLog> paymentGatewayLogs = new List<PaymentGatewayLog>();
        Integer i = 0;
        for (; i < numberOfLogsToBeDeleted; i++) {
            paymentGatewayLogs.add(createAuthLog('pspRef' + i, 'false'));
        }
        for (; i < totalNumberOfLogs; i++) {
            paymentGatewayLogs.add(createAuthLog('pspRef' + i, 'true'));
        }
        insert paymentGatewayLogs;
        for (PaymentGatewayLog paymentGatewayLog : paymentGatewayLogs) {
            Test.setCreatedDate(paymentGatewayLog.Id, Datetime.now().addDays(-31));
        }
        CleanUpGatewayLogsBatch cleanUpGatewayLogsBatch = new CleanUpGatewayLogsBatch(Datetime.now().addDays(-10));
        // when
        Test.startTest();
        Database.executeBatch(cleanUpGatewayLogsBatch);
        Test.stopTest();
        // then
        Assert.areEqual(totalNumberOfLogs - numberOfLogsToBeDeleted, [SELECT COUNT() FROM PaymentGatewayLog]);
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