@isTest
global class AdyenAsyncAdapterTest {

    private static final String TEST_PSP_REFERENCE = '853587067740652G';
    private static final String TEST_PSP_REFERENCE_FAIL = '853587067740652F';
    private static final String TEST_MERCHANT_ACCOUNT = 'TEST_MERCHANT_ACCOUNT';
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
                'status' => AdyenConstants.NOTIFICATION_RECEIVED_CHECKOUT
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
                responseBody.put('resultCode', RESULT_CODE_SUCCESS);
                    // Authorize
                    if(TEST_PAYMENT_TOKEN.equals(paymentMethod.get('storedPaymentMethodId'))) { // Successful Auth
                        additionalData.put('authCode', TEST_AUTH_CODE);
                        amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                    } else { // Failed Auth
                        responseBody.put('resultCode', RESULT_CODE_FAIL);
                        res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                    }

                responseBody.put('additionalData', additionalData);
            } else if(endpoint.containsIgnoreCase('capture')) {
                // Capture
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(requestBody.get('merchantAccount') != '' && requestBody.get('amount') != null) { // Successful Capture
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Capture
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
            } else if(endpoint.containsIgnoreCase('refund')) {
                // Refund
                responseBody.put('reference', TEST_SHOPPER_REFERENCE);
                if(requestBody.get('merchantAccount') != '' && requestBody.get('amount') != null) { // Successful Refund
                    amount.put('value', Integer.valueOf(TEST_AMOUNT*10));
                } else { // Failed Refund
                    res.setStatusCode(AdyenConstants.HTTP_ERROR_CODE);
                }
            }
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
            PaymentGatewayId = pg.Id,
            CurrencyIsoCode = 'USD'
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
    static void testAuthorize_Outbound_Success() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();

        AdyenPaymentHelper.TEST_PAYMENT_METHOD_ID = [SELECT Id FROM CardPaymentMethod ORDER BY CreatedDate DESC LIMIT 1].Id;

        CommercePayments.AuthorizationRequest authRequest = new CommercePayments.AuthorizationRequest(TEST_AMOUNT);
        authRequest.currencyIsoCode = 'USD';

        CommercePayments.CardPaymentMethodRequest cpm = new CommercePayments.CardPaymentMethodRequest(CommercePayments.CardCategory.DebitCard);
        cpm.accountId = [SELECT Id FROM Account ORDER BY CreatedDate DESC LIMIT 1].Id;
        cpm.cardHolderName = 'Johnny Test';
        cpm.cardNumber = TEST_CARD_SUCCESS;
        cpm.expiryMonth = 3;
        cpm.expiryYear = 2030;
        cpm.cvv = '737';
        authRequest.paymentMethod = new CommercePayments.AuthApiPaymentMethodRequest(cpm);

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
        CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
        Test.stopTest();
        System.Assert(captureResponse.toString().contains('[capture-received]'));
		System.Assert(captureResponse.toString().contains(TEST_PSP_REFERENCE));
    }

    @IsTest
    static void testCapture_Outbound_Failure() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();
		AdyenPaymentUtility.skipMerchantAccount = true;
        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TEST_AMOUNT, authId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
        CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
        Test.stopTest();
        System.Assert(captureResponse.toString().contains('SYSTEMERROR'));
    }

    @IsTest
    static void testCapture_Outbound_MissingPaymentAuthorization() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();
        try {
            CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(TEST_AMOUNT, null);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
            CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
            Test.stopTest();
        }
        catch(Exception ex) {
            System.AssertEquals('Payment Authorization Missing', ex.getMessage(), 'Payment Authorization is available.');
        }
    }

    @IsTest
    static void testCapture_Outbound_MissingAmount() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();
        Id authId = [SELECT Id FROM PaymentAuthorization ORDER BY CreatedDate DESC LIMIT 1].Id;
        try {
            CommercePayments.CaptureRequest captureRequest = new CommercePayments.CaptureRequest(null, authId);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(captureRequest, CommercePayments.RequestType.Capture);
            CommercePayments.GatewayResponse captureResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
            Test.stopTest();
        }
        catch(Exception ex) {
            System.AssertEquals('Payment Amount Missing', ex.getMessage(), 'Payment Amount is available.');
        }
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
        AdyenWebhookNotificationHelper.TEST_NOTIFICATION_REQUEST_BODY = JSON.serialize(requestBody);

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
        CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
        Test.stopTest();
        System.Assert(refundResponse.toString().contains(TEST_SHOPPER_REFERENCE));
    }

    @IsTest
    static void testRefund_Outbound_Failure() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();
		AdyenPaymentUtility.skipMerchantAccount = true;
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TEST_AMOUNT, paymentId);
        CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
        CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
        Test.stopTest();
        System.Assert(refundResponse.toString().contains('SYSTEMERROR'));
    }

    @IsTest
    static void testRefund_Outbound_MissingPayment() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();
        try {
            CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(TEST_AMOUNT, null);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
            CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
            Test.stopTest();
        }
        catch(Exception ex) {
            System.AssertEquals('Payment Info Missing', ex.getMessage(), 'Payment Info is available.');
        }
    }

    @IsTest
    static void testRefund_Outbound_MissingAmount() {

        Test.setMock(HttpCalloutMock.class, new EchoHttpMock());
        Test.startTest();
        Id paymentId = [SELECT Id FROM Payment ORDER BY CreatedDate DESC LIMIT 1].Id;
        try {
            CommercePayments.ReferencedRefundRequest refundRequest = new CommercePayments.ReferencedRefundRequest(null, paymentId);
            CommercePayments.PaymentGatewayContext context = new CommercePayments.PaymentGatewayContext(refundRequest, CommercePayments.RequestType.ReferencedRefund);
            CommercePayments.GatewayResponse refundResponse = (CommercePayments.GatewayResponse) adyenAdapter.processRequest(context);
            Test.stopTest();
        }
        catch(Exception ex) {
            System.AssertEquals('Payment Amount Missing', ex.getMessage(), 'Payment Amount is available.');
        }
    }
    public class MyException extends Exception{}
}