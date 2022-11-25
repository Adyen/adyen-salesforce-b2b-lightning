/**
 *  AdyenService will contain all callouts to the Adyen API. as well as build of the body json to be submitted.
 *  Additionally it will parse and serialize any response from the Adyen Payment Gateway.
 */
public with sharing class AdyenService {

    public static final String REFERENCE_MERGE_FIELD   = '{paymentPspReference}';
    public static final String MERCHANT_USERNAME       = '{!$Credential.UserName}';
    public static final String MERCHANT_API_KEY        = '{!$Credential.Password}';


    @TestVisible
    private static final String TEST_ENDPOINT          = 'https://test.com';
    @TestVisible
    private static final String TEST_METHOD            = 'POST';
    @TestVisible
    private static final String CONTENT_TYPE           = 'application/json';

    private String uri;
    private String endpoint;
    private String method;
    private String body;
    private String pspReference;

    public AdyenService(Adyen_Adapter__mdt adyenAdapterMdt) {
        this.uri = Test.isRunningTest() ? TEST_ENDPOINT : adyenAdapterMdt.Endpoint_Path__c + adyenAdapterMdt.Endpoint_Api_Version__c;
        this.method = Test.isRunningTest() ? TEST_METHOD : adyenAdapterMdt.Endpoint_Method__c;
    }

    public void setBody(String body) {
        this.body = body;
    }

    public void setEndpoint(String endpoint) {
        this.endpoint = endpoint;
    }

    public void setReference(String reference) {
        this.pspReference = reference;
    }

    public HttpResponse execute() {
        HttpRequest request = new HttpRequest();
        request.setEndpoint(this.uri + this.endpoint);
        request.setMethod(this.method);
        request.setBody(this.body);

        request.setHeader('Content-Type', CONTENT_TYPE);
        request.setHeader('x-API-key', AdyenService.MERCHANT_API_KEY);

        return (new CommercePayments.PaymentsHttp()).send(request);
    }

    private void mergeEndpointReference() {
        this.endpoint = this.endpoint.replace(REFERENCE_MERGE_FIELD, this.pspReference);
    }

    /**
     *  Serialized version of the Http Response Body received from Adyen to make it easier to work with the JSON.
     */
    public class AdyenNotification {
        public String live                                      {get;set;}
        public List<NotificationItems> notificationItems        {get;set;}
    }
    
    public class NotificationItems {
        public NotificationRequestItem NotificationRequestItem  {get;set;}
    }
    
    public class NotificationRequestItem {
        public Amount amount                                    {get;set;}
        public String eventCode                                 {get;set;}
        public String eventDate                                 {get;set;}
        public String merchantAccountCode                       {get;set;}
        public String paymentMethod                             {get;set;}
        public String originalReference                         {get;set;}
        public String paymentPspReference                       {get;set;}
        public String pspReference                              {get;set;}
        public String reason                                    {get;set;}
        public String success                                   {get;set;}
    }
}