global with sharing class AdyenSchedulableWebhookJob implements Schedulable {
    global void execute(SchedulableContext schedulableContext) {
        AdyenWebhookBatch adyenWebhookBatch = new AdyenWebhookBatch();
        Database.executeBatch(adyenWebhookBatch);
    }
}
