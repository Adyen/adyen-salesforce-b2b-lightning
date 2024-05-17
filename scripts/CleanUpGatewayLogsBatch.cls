public with sharing class CleanUpGatewayLogsBatch implements Database.Batchable<SObject>, Database.Stateful {
    private final List<Exception> exceptions = new List<Exception>();
    private Integer logsDeleted = 0;
    public Datetime logsOlderThanThisDate = Datetime.now().addDays(-30);

    public CleanUpGatewayLogsBatch() {}

    public CleanUpGatewayLogsBatch(Datetime logsOlderThanThisDate) {
        this.logsOlderThanThisDate = logsOlderThanThisDate;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, GatewayRefNumber
            FROM PaymentGatewayLog
            WHERE InteractionType  = 'Authorization' AND InteractionStatus = 'Initiated'
                AND GatewayResultCode = 'false' AND ReferencedEntityId = NULL AND CreatedDate < :logsOlderThanThisDate
        ]);
    }

    public void execute(Database.BatchableContext bc, List<PaymentGatewayLog> paymentGatewayLogs) {
        try {
            Map<String, PaymentGatewayLog> logsByPspReferenceMap = mapLogsByPspReference(paymentGatewayLogs);
            Set<String> pspReferences = logsByPspReferenceMap.keySet();
            List<String> pspRefsWithLogAndRelatedPA = queryRelatedPAReferences(pspReferences);
            List<PaymentGatewayLog> logsToDelete = filterLogsToDelete(logsByPspReferenceMap, pspRefsWithLogAndRelatedPA);
            delete logsToDelete;
            logsDeleted += logsToDelete.size();
        } catch (Exception ex) {
            exceptions.add(ex);
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Payment Gateway Logs deleted: ' + logsDeleted);
        System.debug('Exceptions: ' + exceptions.size());
    }

    private static List<PaymentGatewayLog> filterLogsToDelete(Map<String, PaymentGatewayLog> logMap, List<String> pspRefsWithLogAndRelatedPA) {
        Map<String, PaymentGatewayLog> logsToDeleteMap = logMap;
        for (String pspRefWithLogAndPA : pspRefsWithLogAndRelatedPA) {
            logsToDeleteMap.remove(pspRefWithLogAndPA); // Do not delete Gateway Logs with related PA
        }
        return logsToDeleteMap.values();
    }

    private static Map<String, PaymentGatewayLog> mapLogsByPspReference(List<PaymentGatewayLog> logs) {
        Map<String, PaymentGatewayLog> logsByPspReferenceMap = new Map<String, PaymentGatewayLog>();
        for (PaymentGatewayLog log : logs) {
            logsByPspReferenceMap.put(log.GatewayRefNumber, log);
        }
        return logsByPspReferenceMap;
    }

    private static List<String> queryRelatedPAReferences(Set<String> gatewayLogPSPReferences) {
         List<String> relatedPayAuthPSPs = new List<String>();
         for(PaymentAuthorization paymentAuthorization : [
             SELECT GatewayRefNumber
             FROM PaymentAuthorization
             WHERE GatewayRefNumber IN :gatewayLogPSPReferences
         ]) {
             relatedPayAuthPSPs.add(paymentAuthorization.GatewayRefNumber);
         }
        return relatedPayAuthPSPs;
    }
}