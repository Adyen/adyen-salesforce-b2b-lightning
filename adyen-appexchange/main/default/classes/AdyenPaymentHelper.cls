public with sharing class AdyenPaymentHelper {

    @TestVisible
    public static String TEST_PAYMENT_METHOD_ID;
    @TestVisible
    public static String TEST_NOTIFICATION_REQUEST_BODY;

     /**
     *  Receives Payment Gateway Context from AdyenAsyncAdapter, looks at the context type and then invokes the appropriate Capture or Refund operation
     * 
     * @param paymentGatewayContext
     * @return `CommercePayments.GatewayResponse`
     */
    public static CommercePayments.GatewayResponse handleFulfillmentOrderStatusChange(CommercePayments.paymentGatewayContext paymentGatewayContext){

        CommercePayments.RequestType paymentRequestType = paymentGatewayContext.getPaymentRequestType();
        CommercePayments.PaymentGatewayRequest paymentRequest = paymentGatewayContext.getPaymentRequest();

        System.debug('------------->Adyen payment req type: ' + paymentRequestType);

        try {
            if(paymentRequestType == CommercePayments.RequestType.Authorize)                  return authorize((CommercePayments.AuthorizationRequest)paymentRequest);
            else if(paymentRequestType == CommercePayments.RequestType.Capture)               return AdyenCaptureHelper.capture((CommercePayments.CaptureRequest)paymentRequest);
            else if(paymentRequestType == CommercePayments.RequestType.ReferencedRefund)      return AdyenRefundHelper.refund((CommercePayments.ReferencedRefundRequest)paymentRequest);
            else return null;
        } catch (Exception e) {
            return new CommercePayments.GatewayErrorResponse(String.valueOf(AdyenConstants.HTTP_ERROR_CODE), e.getMessage());
        }
    }

    /**
     * Invoked by handleFulfillmentOrderStatusChange to authorise funds with Adyen
     * 
     * @param authRequest
     * @return `CommercePayments.GatewayResponse`
     * 
     * @see https://docs.adyen.com/api-explorer/#/CheckoutService/v68/post/payments__example_payments-oneclick-direct
     */
    private static CommercePayments.GatewayResponse authorize(CommercePayments.AuthorizationRequest authRequest) {

        System.debug('---------->Adyen: enter authorize method');

        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(AdyenConstants.DEFAULT_ADAPTER_NAME);

        CommercePayments.AuthApiPaymentMethodRequest paymentMethod = authRequest.paymentMethod;
        String currencyCode = authRequest.currencyIsoCode.toUppercase();

        AuthorisationRequest authorizationRequest = new AuthorisationRequest();

        authorizationRequest.amount = new Amount();
        authorizationRequest.amount.currency_x = currencyCode;
        authorizationRequest.amount.value = (authRequest.amount * AdyenPaymentUtility.getAmountMultiplier(currencyCode)).longValue();

        CommercePayments.CardPaymentMethodRequest cpmRequest;
        if(paymentMethod != null) {
            cpmRequest = paymentMethod.cardPaymentMethod;
            CardDetails cardDetails = new CardDetails();
            cardDetails.number_x = cpmRequest.cardNumber;
            cardDetails.expiryMonth = String.valueOf(cpmRequest.expiryMonth);
            cardDetails.expiryYear = String.valueOf(cpmRequest.expiryYear);
            cardDetails.holderName = cpmRequest.cardHolderName;
            cardDetails.cvc = cpmRequest.cvv;
            authorizationRequest.paymentMethod = cardDetails;
        }

        authorizationRequest.reference = AdyenPaymentUtility.getRandomNumber(16);
        authorizationRequest.merchantAccount = adyenAdapterMdt.Merchant_Account__c;
        authorizationRequest.shopperIp = authRequest?.ipAddress;
        authorizationRequest.shopperInteraction = AuthorisationRequest.shopperInteractionEnum.Ecommerce;
        authorizationRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c);
        String body = AdyenPaymentUtility.makeAdyenCompatible(JSON.serialize(authorizationRequest));
        AdyenService client = new AdyenService(adyenAdapterMdt);
        client.setEndpoint(adyenAdapterMdt.Authorize_Endpoint__c);
        client.setBody(body);
        HttpResponse response = client.execute();
        return processAuthResponse(response, authRequest.amount, adyenAdapterMdt.Merchant_Account__c);
    }

    private static CommercePayments.GatewayResponse processAuthResponse(HttpResponse response, Double amount, String merchantAccountName) {
        Map<String,Object> body = (Map<String,Object>)JSON.deserializeUntyped(response.getBody());
        String resultCode = (String)body.get('resultCode');
        if(resultCode != null) {
            System.debug('-----> Adyen accepted request');
            CommercePayments.AuthorizationResponse salesforceAuthResponse = new CommercePayments.AuthorizationResponse();
            if(resultCode == 'Authorised') {
                Map<String,Object> additionalData = (Map<String,Object>)body.get('additionalData');
                salesforceAuthResponse.setGatewayAuthCode((String)additionalData.get('authCode'));
                salesforceAuthResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
            } else {
                salesforceAuthResponse.setGatewayResultCodeDescription((String)body.get('refusalReason'));
                salesforceAuthResponse.setSalesforceResultCodeInfo(AdyenConstants.DECLINE_SALESFORCE_RESULT_CODE_INFO);
            }
            salesforceAuthResponse.setGatewayReferenceNumber((String)body.get('pspReference'));
            salesforceAuthResponse.setAmount(amount);
            salesforceAuthResponse.setGatewayDate(System.now());
            salesforceAuthResponse.setGatewayReferenceDetails(merchantAccountName);
            return salesforceAuthResponse;
        } else {
            System.debug('-----> Adyen rejected request');
            return new CommercePayments.GatewayErrorResponse(
                String.valueOf(response.getStatusCode()),
                String.valueOf(body.get('message'))
            );
        }
    }

    /**
     * ------------------------------------------------------------------------
     * WEBHOOK NOTIFICATIONS
     * ------------------------------------------------------------------------
     */
    public static CommercePayments.GatewayNotificationResponse handleAsyncNotificationCallback(
        CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext,
        String apexName
    ) {
        System.debug('---->Entering AdyenPaymentHelper.handleAsyncNotificationCallback PaymentGatewayNotificationContext = ' + gatewayNotificationContext);
        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = Test.isRunningTest() ? null : gatewayNotificationContext.getPaymentGatewayNotificationRequest();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = new CommercePayments.GatewayNotificationResponse();

        CommercePayments.NotificationSaveResult notificationSaveResult;
        AdyenService.NotificationRequestItem notificationRequestItem;

        notificationRequestItem = parseAdyenNotificationRequest( paymentGatewayNotificationRequest );

        String pspReference = notificationRequestItem.originalReference != null ? notificationRequestItem.originalReference : notificationRequestItem.paymentPspReference;
        String apexAdapterId = AdyenPaymentUtility.retrieveApexAdapterId(pspReference);
        System.debug('---->apexAdapterId =' + apexAdapterId);

        String nameSpacePrefix = '';
        List<ApexClass> adyenApexClass = [SELECT NamespacePrefix from ApexClass WHERE Name = :apexName];
        if (adyenApexClass.size() > 0) {
            nameSpacePrefix = adyenApexClass[0].NamespacePrefix;
        }
        String apexClassId = AdyenPaymentUtility.retrieveApexClassId(apexName, nameSpacePrefix);
        System.debug('---->apexClassId =' + apexClassId);
        
        if(AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE.equalsIgnoreCase(notificationRequestItem.eventCode) || apexAdapterId == apexClassId || Test.isRunningTest()){
        
            notificationSaveResult = createNotificationSaveResult( notificationRequestItem );
        
            if(notificationSaveResult != null) {
                if(notificationSaveResult.isSuccess()) { // Notification is accepted by the platform
                    gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
                    gatewayNotificationResponse.setResponseBody(Blob.valueOf(AdyenConstants.NOTIFICATION_ACCEPTED_RESPONSE));
                    System.debug('---->Exiting AdyenPaymentHelper.handleAsyncNotificationCallback after the notification is accepted = ' + gatewayNotificationResponse);
                } else { // Notification is not accepted by the platform, generate system event
                    String msg = '[accepted] ';
                    if(notificationSaveResult != null && notificationSaveResult.getErrorMessage() != null) {
                        msg += notificationSaveResult.getErrorMessage();
                    }
                    gatewayNotificationResponse.setStatusCode(Integer.valueOf(AdyenConstants.HTTP_ERROR_CODE));
                    gatewayNotificationResponse.setResponseBody(Blob.valueOf(msg));
                }
            } else {
                String msg = '[accepted] But unsupported notification type = ' + notificationRequestItem.eventCode;
                gatewayNotificationResponse.setResponseBody(Blob.valueOf(msg));
                gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
            }
        } else {
            String msg = '[accepted] But not processed - wrong payment adapter or wrong instance';
            gatewayNotificationResponse.setResponseBody(Blob.valueOf(msg));
            gatewayNotificationResponse.setStatusCode(AdyenConstants.HTTP_SUCCESS_CODE);
            System.debug('---->Exiting AdyenPaymentHelper.handleAsyncNotificationCallback after identifying that it was the wrong payment adapter = ' + gatewayNotificationResponse);
        }
        return gatewayNotificationResponse;
    }

    /**
     * Take the http request from the async notification callback and deserializes it into AdyenNotificationResponse.
     *
     * @param adyenNotificationRequestPayload   The body of the Adyen notification request.
     * @return AdyenService.AdyenNotificationRequest         The deserialized version of the Adyen nodification request.
     *
     * @see https://docs.adyen.com/development-resources/webhooks/understand-notifications
     */
    public static AdyenService.NotificationRequestItem parseAdyenNotificationRequest(CommercePayments.PaymentGatewayNotificationRequest notificationRequest) {
        String requestBody = Test.isRunningTest() ? TEST_NOTIFICATION_REQUEST_BODY : AdyenPaymentUtility.makeSalesforceCompatible(notificationRequest.getRequestBody().toString());
        AdyenService.AdyenNotification adyenNotification  = (AdyenService.AdyenNotification) JSON.deserialize(requestBody, AdyenService.AdyenNotification.class);
        AdyenService.NotificationRequestItem notificationRequestItem = new AdyenService.NotificationRequestItem();
        if(adyenNotification != null) {
            for(AdyenService.NotificationItems notificationItem : adyenNotification.notificationItems) {
                if(notificationItem.NotificationRequestItem != null) {
                    notificationRequestItem = notificationItem.NotificationRequestItem;
                }
            }
        }
        return notificationRequestItem;
    }


    /**
     * Creates and records (ie saves) the notificationsaveresult.
     *
     * @param adyenNotificationResponse
     * @return CommercePayments.NotificationSaveResult.
     */
    private static CommercePayments.NotificationSaveResult createNotificationSaveResult( AdyenService.NotificationRequestItem notificationRequestItem ) {

        CommercePayments.BaseNotification notification = null;
        CommercePayments.NotificationStatus notificationStatus = null;
        CommercePayments.SalesforceResultCode notificationStatusSF = null;

        if(!Boolean.valueOf(notificationRequestItem.success)){
            notificationStatus = CommercePayments.NotificationStatus.Failed;
            notificationStatusSF = CommercePayments.SalesforceResultCode.Decline; 
        } else {
            notificationStatus = CommercePayments.NotificationStatus.Success;
            notificationStatusSF = CommercePayments.SalesforceResultCode.Success; 
        }

        if (AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE.equalsIgnoreCase(notificationRequestItem.eventCode) ||
            AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE_FAILED.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            notification = new CommercePayments.CaptureNotification();
        } else if ( AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            notification = new CommercePayments.ReferencedRefundNotification();
        /*
        } else if ( AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            // TODO : When SF OMS supports cancel notifications, change this object to a CancelNotification
            notification = new CommercePayments.AuthorizationReversalNotification();
        } else if ( AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE.equalsIgnoreCase(notificationRequestItem.eventCode)) {
            // TODO : When SF OMS Supports auth notifications, change this object to an AuthorizationNotification
            notification = new CommercePayments.AuthorizationNotification();
        */
        } else {
            System.debug('---> Exiting AdyenPaymentHelper.createNotificationSaveResult after ignoring unsupported notification = ' + notificationRequestItem.eventCode);
            return null;
        }

        notification.setGatewayDate(System.now());
        notification.setStatus(notificationStatus);
        notification.setSalesforceResultCodeInfo(new CommercePayments.SalesforceResultCodeInfo(notificationStatusSF));
        notification.setGatewayReferenceNumber(notificationRequestItem.pspReference);
        notification.setGatewayResultCode(notificationRequestItem.eventCode);
        notification.setGatewayResultCodeDescription(notificationRequestItem.reason);
        if(String.isBlank(notificationRequestItem.reason) && notificationStatus == CommercePayments.NotificationStatus.Success) {
            if ( AdyenConstants.NOTIFICATION_REQUEST_TYPE_CAPTURE.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                notification.setGatewayMessage('[capture-complete]');
            } else if ( AdyenConstants.NOTIFICATION_REQUEST_TYPE_REFUND.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                notification.setGatewayMessage('[refund-complete]');
            } else if ( AdyenConstants.NOTIFICATION_REQUEST_TYPE_CANCEL.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                notification.setGatewayMessage('[cancel-complete]');
            } else if ( AdyenConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE.equalsIgnoreCase(notificationRequestItem.eventCode)) {
                notification.setGatewayMessage('[authorise-complete]');
            }
        } else {
            notification.setGatewayMessage(notificationRequestItem.reason);
        }

        if(notificationRequestItem.amount != null) {
            Decimal value = notificationRequestItem.amount.value;
            value = value / AdyenPaymentUtility.getAmountMultiplier(notificationRequestItem.amount.currency_x);
            Double dValue = value;
            notification.setAmount(dValue);
        }

        return CommercePayments.NotificationClient.record(notification);
    }
}