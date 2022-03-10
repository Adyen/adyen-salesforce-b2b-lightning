/**
 *   @todo this really needs asserts badly but how do we work with the return from the adapter?
 */
@IsTest
global class AdyenAsyncAdapterTest {

    private static final String TEST_PSP_REFERENCE = '853587067740652G';
    private static final String TEST_PSP_REFERENCE_FAIL = '853587067740652F';
    private static final String TEST_MERCHANT_REFERENCE = 'TEST_MERCHANT_REFERENCE';
    private static final String TEST_SHOPPER_REFERENCE = 'TEST_SHOPPER_REFERENCE';
    private static final String TEST_CARD_SUCCESS = '4242424242424242';
    private static final String TEST_PAYMENT_TOKEN = 'TEST_PAYMENT_TOKEN';
    private static final String TEST_AUTH_CODE = 'TEST_AUTH_CODE';
    private static final String RESULT_CODE_SUCCESS = 'Authorised';
    private static final String RESULT_CODE_FAIL = 'Failure';
    private static final Double TEST_AMOUNT = 19.99;

    private static final AdyenAsyncAdapter adyenAdapter = new AdyenAsyncAdapter();

    global class EchoHttpMock implements HttpCalloutMock {
        global HttpResponse respond(HttpRequest req) {

            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
            Map<String, Object> responseBody = new Map<String, Object> {
                'pspReference' => TEST_PSP_REFERENCE,
                'status' => 'recieved'
            };
            Map<String, Object> additionalData = new Map<String, Object>();
            Map<String, Object> amount = new Map<String, Object> {
                'currency' => 'USD',
                'value' => 0
            };

            String endpoint = req.getEndpoint();
            Map<String, Object> requestBody = (Map<String, Object>)JSON.deserializeUntyped(req.getBody());

            if(endpoint.containsIgnoreCase('payment')) {
                Map<String, Object> paymentMethod = (Map<String, Object>)JSON.deserializeUntyped(JSON.serialize((requestBody.get('paymentMethod'))));
                Object spm = requestBody.get('storePaymentMethod');
                Boolean isTokenize = spm != null && Boolean.valueOf(spm);
                responseBody.put('resultCode', RESULT_CODE_SUCCESS);
                if(isTokenize) {
                    // Tokenize
                    if(TEST_CARD_SUCCESS.equals(paymentMethod.get('number'))) { // Successful Tokenize
                        additionalData.put('recurring.recurringDetailReference', TEST_PAYMENT_TOKEN);
                        additionalData.put('recurring.shopperReference', TEST_SHOPPER_REFERENCE);
                    } else { // Failed Tokenize
                        responseBody.put('resultCode', RESULT_CODE_FAIL);
                        res.setStatusCode(AdyenService.HTTP_ERROR_CODE);
                    }
                } else {
                    // Authorize
                    if(TEST_PAYMENT_TOKEN.equals(paymentMethod.get('storedPaymentMethodId'))) { // Successful Auth
                        additionalData.put('authCode', TEST_AUTH_CODE);
                        amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                    } else { // Failed Auth
                        responseBody.put('resultCode', RESULT_CODE_FAIL);
                        res.setStatusCode(AdyenService.HTTP_ERROR_CODE);
                    }
                }
                responseBody.put('additionalData', additionalData);
            } else if(endpoint.containsIgnoreCase('capture')) {
                // Capture
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(TEST_PSP_REFERENCE.equals(requestBody.get('originalReference'))) { // Successful Capture
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Capture
                    res.setStatusCode(AdyenService.HTTP_ERROR_CODE);
                }
            } else if(endpoint.containsIgnoreCase('refund')) {
                // Refund
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(TEST_PSP_REFERENCE.equals(requestBody.get('originalReference'))) { // Successful Refund
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Refund
                    res.setStatusCode(AdyenService.HTTP_ERROR_CODE);
                }
            } else if(endpoint.containsIgnoreCase('cancel')) {
                if(!TEST_PSP_REFERENCE.equals(requestBody.get('reference'))) { // Failed Cancel
                    res.setStatusCode(AdyenService.HTTP_ERROR_CODE);
                }
            }

            if(!endpoint.containsIgnoreCase('cancel')) responseBody.put('amount', amount);
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }

    @TestSetup
    static void makeData() {
        Account a = new Account(Name = 'Test Account');
        insert a;

        CardPaymentMethod cpm = new CardPaymentMethod(
            GatewayToken = TEST_PAYMENT_TOKEN,
            CardHolderName = 'Test Cardholder',
            Email = 'test@asdf.com',
            Status = 'Active',
            ProcessingMode = 'External'
        );
        insert cpm;

        PaymentGateway pg = new PaymentGateway(
            PaymentGatewayName = 'Adyen',
            Status = 'Active',
            ExternalReference = 'Adyen_Component',
            MerchantCredentialId = [SELECT Id FROM NamedCredential LIMIT 1]?.Id,
            PaymentGatewayProviderId = [SELECT Id FROM PaymentGatewayProvider LIMIT 1]?.Id
        );
        insert pg;

        PaymentAuthorization pa = new PaymentAuthorization(
            AccountId = a.Id,
            PaymentMethodId = cpm.Id,
            Amount = TEST_AMOUNT,
            GatewayRefNumber = TEST_PSP_REFERENCE,
            Status = 'Processed',
            ProcessingMode = 'External',
            PaymentGatewayId = pg.Id
        );
        insert pa;

        Payment p = new Payment(
            AccountId = a.Id,
            PaymentMethodId = cpm.Id,
            Amount = TEST_AMOUNT,
            GatewayRefNumber = TEST_PSP_REFERENCE,
            Status = 'Processed',
            ProcessingMode = 'External',
            Type = 'Capture',
            PaymentGatewayId = pg.Id,
            PaymentAuthorizationId = pa.Id
        );
        insert p;
    }

    @IsTest
    static void testTokenize_Outbound_Success() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();

        AdyenPaymentHelper.TEST_PMID = [SELECT Id FROM CardPaymentMethod ORDER BY CreatedDate DESC LIMIT 1].Id;

        Id paymentGatewayId = [SELECT Id FROM PaymentGateway ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.PaymentMethodTokenizationRequest tokenizeRequest = new CommercePayments.PaymentMethodTokenizationRequest(paymentGatewayId);
        CommercePayments.CardPaymentMethodRequest cpm = new CommercePayments.CardPaymentMethodRequest(CommercePayments.CardCategory.DebitCard);
        cpm.accountId = [SELECT Id FROM Account ORDER BY CreatedDate DESC LIMIT 1].Id;
        cpm.cardHolderName = 'Johnny Test';
        cpm.cardNumber = TEST_CARD_SUCCESS;
        cpm.expiryMonth = 3;
        cpm.expiryYear = 2030;
        cpm.cvv = '737';
        tokenizeRequest.cardPaymentMethod = cpm;
        tokenizeRequest.address = new CommercePayments.AddressRequest( '123 Main St', 'Chicago', 'IL', 'USA', '60606');

        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(tokenizeRequest, CommercePayments.RequestType.Tokenize);
        CommercePayments.PaymentMethodTokenizationResponse tokenizeResponse = (CommercePayments.PaymentMethodTokenizationResponse) adyenAdapter.processRequest(context);

        Test.stopTest();

        System.Assert(tokenizeResponse.toString().contains(TEST_PAYMENT_TOKEN));
    }

    @IsTest
    static void testAuthorize_Outbound_Success() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();

        AdyenPaymentHelper.TEST_PMID = [SELECT Id FROM CardPaymentMethod ORDER BY CreatedDate DESC LIMIT 1].Id;

        CommercePayments.AuthorizationRequest authRequest = new CommercePayments.AuthorizationRequest(TEST_AMOUNT);
        authRequest.currencyIsoCode = 'USD';
        authRequest.paymentMethod = new CommercePayments.AuthApiPaymentMethodRequest();

        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(authRequest, CommercePayments.RequestType.Authorize);
        CommercePayments.AuthorizationResponse authResponse = (CommercePayments.AuthorizationResponse) adyenAdapter.processRequest(context);

        Test.stopTest();

        System.Assert(authResponse.toString().contains(TEST_PSP_REFERENCE));
    }

    @IsTest
    static void testCapture_Outbound_Success() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();

        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TEST_AMOUNT, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.CaptureResponse captureResponse = (CommercePayments.CaptureResponse) adyenAdapter.processRequest(context);

        Test.stopTest();

        System.Assert(captureResponse.toString().contains(TEST_PSP_REFERENCE));
    }

    @IsTest
    static void testCapture_Inbound_Success() {

        AdyenService.NotificationRequestItem nri = new AdyenService.NotificationRequestItem();
        Amount a = new Amount();
        a.currency_x = 'USD';
        a.value = (Long)Integer.valueOf(TEST_AMOUNT*10);
        nri.amount = a;
        nri.eventCode = AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE;
        nri.originalReference = TEST_PSP_REFERENCE;
        nri.pspReference = TEST_PSP_REFERENCE;
        nri.success = 'true';
        nri.reason = 'TEST';
        AdyenService.NotificationItems item = new AdyenService.NotificationItems();
        item.notificationRequestItem = nri;
        Map<String, Object> requestBody = new Map<String, Object>{
            'live' => false,
            'notificationItems' => new List<AdyenService.NotificationItems>{item}
        };
        AdyenPaymentHelper.TEST_NR_BODY = JSON.serialize(requestBody);

        Test.startTest();
        CommercePayments.GatewayNotificationResponse captureResponse = adyenAdapter.processNotification(null);
        Test.stopTest();

        System.Assert(!captureResponse.toString().containsIgnoreCase('error'));
    }

    @IsTest
    static void testRefund_Outbound_Success() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();

        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TEST_AMOUNT, paymentId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.ReferencedRefundResponse refundResponse = (CommercePayments.ReferencedRefundResponse) adyenAdapter.processRequest(context);

        Test.stopTest();

        System.Assert(refundResponse.toString().contains(TEST_PSP_REFERENCE));
    }

    @IsTest
    static void testCancel_Outbound_Success() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();

        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.AuthorizationReversalRequest cancelRequest = new CommercePayments.AuthorizationReversalRequest(TEST_AMOUNT, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(cancelRequest, CommercePayments.RequestType.AuthorizationReversal);
        CommercePayments.AuthorizationReversalResponse cancelResponse = (CommercePayments.AuthorizationReversalResponse) adyenAdapter.processRequest(context);

        Test.stopTest();

        System.Assert(cancelResponse.toString().contains(TEST_PSP_REFERENCE));
    }

    public class MyException extends Exception{}
}