@IsTest
private class LogEntryTest {
    @IsTest
    static void insertLogExceptionTest() {
        // given
        Exception error = new AuraHandledException('error');
        String logName = 'Log Name';
        String className = 'ClassName';
        String methodName = 'MethodName';
        String message = 'message';
        String details = 'details';
        Id cartId = null;
        // when
        LogEntry.insertLogException(error, logName, className, methodName);
        LogEntry.insertLogException(error, logName, className, methodName, details);
        LogEntry.insertLogException(error, logName, className, methodName, cartId);
        LogEntry.insertLogError(logName, cartId, message, details);
        // then
        Assert.areEqual(4, [SELECT COUNT() FROM LogEntry__c WHERE Severity__c LIKE :LogEntry.SeverityLevel.ERROR.name()]);

        // given a critical exception
        error = new AdyenDropInController.CriticalException();
        // when
        LogEntry.insertLogException(error, logName, className, methodName, cartId);
        // then
        Assert.areEqual(1, [SELECT COUNT() FROM LogEntry__c WHERE Severity__c LIKE :LogEntry.SeverityLevel.CRITICAL.name()]);
    }

    @IsTest
    static void insertInformationLogTest() {
        // given
        String logName = 'Log Name';
        String message = 'message';
        String details = 'details';
        // when
        LogEntry.insertLogInformation(logName, null, message, details);
        // then
        Assert.areEqual(1, [SELECT COUNT() FROM LogEntry__c WHERE Severity__c LIKE :LogEntry.SeverityLevel.INFO.name()]);
    }
}