public with sharing class AdyenB2BConstants {
    public static final String EXTERNAL_PLATFORM_NAME_FOR_APP_INFO = 'Adyen Salesforce B2B LWR';
    public static final String ADYEN_LIBRARY_NAME_FOR_APP_INFO = 'adyen-apex-api-library';
    public static final String ADYEN_LIBRARY_VERSION_FOR_APP_INFO = '3.1.0';
    public static final String MERCHANT_APP_NAME_FOR_APP_INFO = 'adyen-salesforce-b2b-lwr';
    public static final String MERCHANT_APP_VERSION_FOR_APP_INFO = '2.1.0';

    public static final String DEFAULT_PAYMENT_GATEWAY_NAME = 'Adyen';
    public static final String CARD_PAYMENT_METHOD_TYPE = 'scheme';
    public static final String SEPA_DIRECT_DEBIT = 'sepadirectdebit';
    public static final String ACH_DIRECT_DEBIT = 'ach';
    public static final String BANCONTACT_CARD_PAYMENT_METHOD_TYPE = 'bcmc';
    public static final String BANCONTACT_MOBILE_PAYMENT_METHOD_TYPE = 'bcmc_mobile';
    public static final String NOTIFICATION_REQUEST_TYPE_AUTHORISE = 'authorisation';

    public enum PaymentAuthorizationStatus { DRAFT, CANCELED, PENDING, PROCESSED, FAILED }
    public enum PaymentGatewayLogStatus { NOOP, INITIATED, SUCCESS, FAILED, TIMEOUT }

    public static final Map<String,String> ADYEN_PAYMENT_TYPE_TO_SF_TYPE = new Map<String,String>{
            'visa' => 'Visa',
            'amex' => 'American Express',
            'mc' => 'Master Card',
            'diners' => 'Diners Club',
            'jcb' => 'JCB',
            'maestro' => 'Maestro'
    };

    public static final Set<String> THREE_DECIMAL_CURRENCIES = new Set<String> {
            'BHD','IQD','JOD','KWD','LWD','OMR','TND'
    };
    public static final Set<String> ZERO_DECIMAL_CURRENCIES  = new Set<String> {
            'CVE', 'DJF', 'GNF', 'IDR', 'JPY', 'KMF', 'KRW',
            'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };
}