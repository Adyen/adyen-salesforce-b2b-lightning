@IsTest
private class AdyenSchedulableWebhookJobTest {
    @IsTest
    static void scheduleJobTest() {
        // given
        AdyenSchedulableWebhookJob webhookJob = new AdyenSchedulableWebhookJob();
        String sch = '0 0 * * * ?';
        // when
        Test.startTest();
        String jobId = System.schedule('Adyen Webhook Job 0', sch, webhookJob);
        Test.stopTest();
        // then
        CronTrigger ct = [SELECT CronExpression FROM CronTrigger WHERE Id = :jobId];
        Assert.areEqual(sch, ct.CronExpression);
    }
}
