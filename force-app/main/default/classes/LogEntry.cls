public with sharing class LogEntry {
    public enum SeverityLevel { INFO, ERROR, CRITICAL }

    public static void insertLogException(Exception error, String logName, String className, String methodName, Id cartId, LogEntry.SeverityLevel severity, String details) {
        LogEntry__c logEntry = new LogEntry__c();
        logEntry.RecordTypeId = Schema.SObjectType.LogEntry__c.getRecordTypeInfosByDeveloperName().get('Exception').getRecordTypeId();
        logEntry.Name = logName;
        logEntry.Class_Name__c = className;
        logEntry.Method_Name__c = methodName;
        logEntry.Cart__c = cartId;
        logEntry.Message__c = AdyenB2BUtils.safeAssignTextFieldValue(error?.getMessage(), LogEntry__c.Message__c.getDescribe());
        logEntry.Details__c = AdyenB2BUtils.safeAssignTextFieldValue(details, LogEntry__c.Details__c.getDescribe());
        logEntry.StackTrace__c = AdyenB2BUtils.safeAssignTextFieldValue(error?.getStackTraceString(), LogEntry__c.StackTrace__c.getDescribe());
        logEntry.Severity__c = severity == null ? SeverityLevel.ERROR.name() : severity.name();
        insert logEntry;
    }

    public static void insertLogInformation(String logName, Id cartId, String message, String details) {
        Id informationRecordTypeId = Schema.SObjectType.LogEntry__c.getRecordTypeInfosByDeveloperName().get('Information').getRecordTypeId();
        insertLogWithDetails(logName, cartId, message, details, SeverityLevel.INFO, informationRecordTypeId);
    }

    public static void insertLogError(String logName, Id cartId, String message, String details) {
        Id exceptionRecordTypeId = Schema.SObjectType.LogEntry__c.getRecordTypeInfosByDeveloperName().get('Exception').getRecordTypeId();
        insertLogWithDetails(logName, cartId, message, details, SeverityLevel.ERROR, exceptionRecordTypeId);
    }

    private static void insertLogWithDetails(String logName, Id cartId, String message, String details, SeverityLevel severity, Id recordTypeId) {
        LogEntry__c logEntry = new LogEntry__c();
        logEntry.RecordTypeId = recordTypeId;
        logEntry.Name = logName;
        logEntry.Cart__c = cartId;
        logEntry.Message__c = AdyenB2BUtils.safeAssignTextFieldValue(message, LogEntry__c.Message__c.getDescribe());
        logEntry.Details__c = AdyenB2BUtils.safeAssignTextFieldValue(details, LogEntry__c.Details__c.getDescribe());
        logEntry.Severity__c = severity.name();
        insert logEntry;
    }

    public static void insertLogException(Exception error, String logName, String className, String methodName, Id cartId) {
        LogEntry.SeverityLevel severity = error instanceof AdyenDropInController.CriticalException ? SeverityLevel.CRITICAL : SeverityLevel.ERROR;
        insertLogException(error, logName, className, methodName, cartId, severity, null);
    }

    public static void insertLogException(Exception error, String logName, String className, String methodName) {
        insertLogException(error, logName, className, methodName, null, null, null);
    }

    public static void insertLogException(Exception error, String logName, String className, String methodName, String details) {
        insertLogException(error, logName, className, methodName, null, null, details);
    }
}

