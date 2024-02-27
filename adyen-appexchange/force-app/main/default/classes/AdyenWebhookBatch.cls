public without sharing class AdyenWebhookBatch implements Database.Batchable<SObject>, Database.Stateful {
    public List<Exception> exceptions = new List<Exception>();
    public String additionalQueryFilters;
    public String orderByClause;
    public List<String> sendEmailToTheseAddresses = new List<String>();
    public Set<String> sendNotificationToTheseUsers = new Set<String>();
    public Id organizationWideEmailAddressId;

    public AdyenWebhookBatch() {
        this(null, 'ORDER BY CreatedDate');
    }

    public AdyenWebhookBatch(String additionalQueryFilters, String orderByClause) {
        this.additionalQueryFilters = additionalQueryFilters;
        this.orderByClause = orderByClause;
    }

    public Database.QueryLocator start(Database.BatchableContext BC) {
        String baseQuery = 'SELECT InteractionStatus, GatewayRefNumber, GatewayResultCode FROM PaymentGatewayLog WHERE InteractionType = \'Authorization\' AND InteractionStatus = \'Initiated\' ';
        String finalQuery = buildQuery(baseQuery, additionalQueryFilters, orderByClause);
        return Database.getQueryLocator(finalQuery);
    }

    public void execute(Database.BatchableContext BC, List<PaymentGatewayLog> paymentGatewayLogs) {
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
            sendErrorEmail(asyncJob);
            sendCustomNotification(asyncJob);
        }
    }

    private void sendErrorEmail(AsyncApexJob asyncJob) {
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        String[] toAddresses = sendEmailToTheseAddresses.isEmpty() ? new String[] {asyncJob.CreatedBy.Email} : sendEmailToTheseAddresses;
        Id senderEmailId = getSenderEmailId(organizationWideEmailAddressId);
        if (senderEmailId != null) {
            mail.setOrgWideEmailAddressId(senderEmailId);
        }
        mail.setToAddresses(toAddresses);
        mail.setSubject('Errors occurred during Adyen Webhook batch process.');
        mail.setHtmlBody(buildHtmlBodyFor(asyncJob, exceptions));
        Messaging.sendEmail(new Messaging.Email[] { mail });
    }

    private void sendCustomNotification(AsyncApexJob asyncJob) {
        Messaging.CustomNotification notification = new Messaging.CustomNotification();
        notification.setTitle('Errors occurred during Adyen Webhook batch process.');
        notification.setBody(buildBodyFor(exceptions));
        notification.setNotificationTypeId([SELECT Id FROM CustomNotificationType WHERE DeveloperName = 'Adyen_Webhook_Job_Exception'].Id);
        notification.setTargetId('000000000000000AAA');
        Set<String> usersIdToBeNotified = sendNotificationToTheseUsers.isEmpty() ? new Set<String>{asyncJob.CreatedById} : sendNotificationToTheseUsers;
        notification.send(usersIdToBeNotified);
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

    private static void processRecords(Map<String, PaymentGatewayLog> logMap, List<PaymentAuthorization> authorizations) {
        List<PaymentGatewayLog> logsToUpdate = new List<PaymentGatewayLog>();
        List<PaymentAuthorization> authsToUpdate = new List<PaymentAuthorization>();

        for (PaymentAuthorization auth : authorizations) {
            PaymentGatewayLog log = logMap.get(auth.GatewayRefNumber);
            if (auth.Status.equalsIgnoreCase('Pending')) {
                auth.Status = Boolean.valueOf(log.GatewayResultCode) ? 'Processed' : 'Failed';
                authsToUpdate.add(auth);
            }
            log.InteractionStatus = 'Success';
            log.ReferencedEntityId = auth.Id;
            log.OrderPaymentSummaryId = auth.OrderPaymentSummaryId;
            logsToUpdate.add(log);
        }

        update authsToUpdate;
        update logsToUpdate;
    }

    private static String buildHtmlBodyFor(AsyncApexJob asyncJob, List<Exception> exceptions) {
        String emailPlainText = 'The Adyen Webhook batch job processed {0} out of {1} batch(es). </br>';
        List<Integer> parameters = new List<Integer>{asyncJob.JobItemsProcessed, asyncJob.TotalJobItems};
        String formattedEmailText = String.format(emailPlainText, parameters);
        String body = formattedEmailText + '</br><b>' + exceptions.size() + '</b> exception(s) occurred during Adyen Webhook batch processing:<br/><br/>';
        for (Exception singleException : exceptions) {
            body += singleException.toString() + '<br/>';
        }
        return body;
    }

    private static String buildBodyFor(List<Exception> exceptions) {
        String body = '';
        for (Exception singleException : exceptions) {
            body += singleException.getMessage();
        }
        if (body.length() > 750) {
            return body.substring(0, 750);
        } else {
            return body;
        }
    }

    private static Id getSenderEmailId(Id orgWideEmailAddressId) {
        Id senderEmailId = orgWideEmailAddressId;
        if (senderEmailId == null) {
            List<OrgWideEmailAddress> orgWideEmailAddresses = [SELECT Id FROM OrgWideEmailAddress WHERE Purpose = 'DefaultNoreply' LIMIT 1];
            if (!orgWideEmailAddresses.isEmpty()) {
                senderEmailId = orgWideEmailAddresses[0].Id;
            }
        }
        return senderEmailId;
    }

}
