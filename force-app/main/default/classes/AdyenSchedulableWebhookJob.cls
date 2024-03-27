public with sharing class AdyenSchedulableWebhookJob implements Schedulable {
    public void execute(SchedulableContext schedulableContext) {
        AdyenWebhookBatch adyenWebhookBatch = new AdyenWebhookBatch();
        Database.executeBatch(adyenWebhookBatch);
    }
}
