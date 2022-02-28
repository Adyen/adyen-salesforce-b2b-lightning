public with sharing class AdyenConstants {
    @TestVisible
    public static String TEST_PMID;
    @TestVisible
    public static String TEST_NR_BODY;

    @TestVisible
    public static final String DEFAULT_ADAPTER_NAME         = 'AdyenDefault';
    @TestVisible
    public static final String NOTIFICATION_REQUEST_TYPE_CANCEL = 'cancellation';
    @TestVisible
    public static final String NOTIFICATION_REQUEST_TYPE_AUTHORISE = 'authorization';
    @TestVisible
    public static final String NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED = 'capture-failed';
    @TestVisible
    public static final String NOTIFICATION_REQUEST_TYPE_CAPTURE  = 'capture';
    @TestVisible
    public static final String NOTIFICATION_REQUEST_TYPE_REFUND   = 'refund';
    @TestVisible
    public static final String NOTIFICATION_ACCEPTED_RESPONSE     = '[accepted]';

    public static final Set<String> threeDecimalCurrencies = new Set<String> {
        'BHD','IQD','JOD','KWD','LWD','OMR','TND'
    };
    public static final Set<String> zeroDecimalCurrencies  = new Set<String> {
        'CVE', 'DJF', 'GNF', 'IDR', 'JPY', 'KMF', 'KRW',
        'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };

    public static final CommercePayments.SalesforceResultCodeInfo SUCCESS_SALESFORCE_RESULT_CODE_INFO =
            new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.Success);

    public static final CommercePayments.SalesforceResultCodeInfo DECLINE_SALESFORCE_RESULT_CODE_INFO =
            new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.Decline);

    public static final CommercePayments.SalesforceResultCodeInfo SYSTEM_ERROR_SALESFORCE_RESULT_CODE_INFO =
            new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.SystemError);

    public static final CommercePayments.SalesforceResultCodeInfo VALIDATION_ERROR_SALESFORCE_RESULT_CODE_INFO =
            new CommercePayments.SalesforceResultCodeInfo(CommercePayments.SalesforceResultCode.ValidationError);

    public static final Integer HTTP_SUCCESS_CODE      = 200;
    public static final Integer HTTP_ERROR_CODE        = 400;
}