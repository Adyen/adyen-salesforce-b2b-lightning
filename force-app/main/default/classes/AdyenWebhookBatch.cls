public with sharing class AdyenWebhookBatch implements Database.Batchable<SObject>, Database.Stateful {
    public List<Exception> exceptions = new List<Exception>();
    public String additionalQueryFilters;
    public String orderByClause;

    public AdyenWebhookBatch() {
        this(null, 'ORDER BY CreatedDate');
    }

    public AdyenWebhookBatch(String additionalQueryFilters, String orderByClause) {
        this.additionalQueryFilters = additionalQueryFilters;
        this.orderByClause = orderByClause;
    }

    public Database.QueryLocator start(Database.BatchableContext bc) {
        String baseQuery = 'SELECT InteractionStatus, GatewayRefNumber, GatewayResultCode FROM PaymentGatewayLog WHERE InteractionType = \'Authorization\' AND InteractionStatus = \'Initiated\' AND ReferencedEntityId = NULL ';
        String finalQuery = buildQuery(baseQuery, additionalQueryFilters, orderByClause);
        return Database.getQueryLocator(finalQuery);
    }

    public void execute(Database.BatchableContext bc, List<PaymentGatewayLog> paymentGatewayLogs) {
        try {
            Map<String, PaymentGatewayLog> logsByPspReferenceMap = mapLogsByPspReference(paymentGatewayLogs);
            Set<String> pspReferences = logsByPspReferenceMap.keySet();
            List<PaymentAuthorization> authorizations = queryAuthorizations(pspReferences);
            processRecords(logsByPspReferenceMap, authorizations);
        } catch (Exception ex) {
            exceptions.add(ex);
        }
    }

    public void finish(Database.BatchableContext bc) {
        if (!exceptions.isEmpty()) {
            AsyncApexJob asyncJob = [
                SELECT NumberOfErrors, JobItemsProcessed, TotalJobItems, CreatedBy.Email
                FROM AsyncApexJob
                WHERE Id = :bc.getJobId()
            ];
            String message = String.format('{0} error(s) found while processing async apex job id {1}', new List<String>{String.valueOf(asyncJob.NumberOfErrors), asyncJob.Id});
            LogEntry.insertLogError('Adyen Web Hook Batch Failed', null, message, buildBodyFor(exceptions));
        }
    }

    private static void processRecords(Map<String, PaymentGatewayLog> logMap, List<PaymentAuthorization> authorizations) {
        List<PaymentGatewayLog> logsToUpdate = new List<PaymentGatewayLog>();
        List<PaymentAuthorization> authsToUpdate = new List<PaymentAuthorization>();

        for (PaymentAuthorization auth : authorizations) {
            PaymentGatewayLog log = logMap.get(auth.GatewayRefNumber);
            if (auth.Status.equalsIgnoreCase(AdyenB2BConstants.PaymentAuthorizationStatus.PENDING.name())) {
                auth.Status = Boolean.valueOf(log.GatewayResultCode) ? AdyenB2BConstants.PaymentAuthorizationStatus.PROCESSED.name() : AdyenB2BConstants.PaymentAuthorizationStatus.FAILED.name();
                authsToUpdate.add(auth);
            }
            log.InteractionStatus = AdyenB2BConstants.PaymentGatewayLogStatus.SUCCESS.name();
            log.ReferencedEntityId = auth.Id;
            log.OrderPaymentSummaryId = auth.OrderPaymentSummaryId;
            log.GatewayMessage = '[accepted] and processed by batch job';
            logsToUpdate.add(log);
        }

        update authsToUpdate;
        update logsToUpdate;
    }

    private static String buildQuery(String baseQuery, String filters, String orderBy) {
        if (String.isNotBlank(filters)) {
            baseQuery += 'AND ' + filters + ' ';
        }
        return baseQuery + orderBy;
    }

    private static Map<String, PaymentGatewayLog> mapLogsByPspReference(List<PaymentGatewayLog> logs) {
        Map<String, PaymentGatewayLog> logsByPspReferenceMap = new Map<String, PaymentGatewayLog>();
        for (PaymentGatewayLog log : logs) {
            logsByPspReferenceMap.put(log.GatewayRefNumber, log);
        }
        return logsByPspReferenceMap;
    }

    private static List<PaymentAuthorization> queryAuthorizations(Set<String> pspReferences) {
        return [
            SELECT Status, GatewayRefNumber, OrderPaymentSummaryId
            FROM PaymentAuthorization
            WHERE GatewayRefNumber IN :pspReferences
        ];
    }

    private static String buildBodyFor(List<Exception> exceptions) {
        String body = '';
        for (Exception singleException : exceptions) {
            body += singleException.getMessage() + '. Stack Trace: ' + singleException.getStackTraceString() + '\n';
        }
        return body;
    }
}
