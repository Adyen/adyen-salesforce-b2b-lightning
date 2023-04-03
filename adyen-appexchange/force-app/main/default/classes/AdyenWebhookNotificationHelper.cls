public with sharing class AdyenWebhookNotificationHelper {

    public static String TEST_NOTIFICATION_REQUEST_BODY;

    /**
     * ------------------------------------------------------------------------
     * HANDLE WEBHOOK NOTIFICATIONS
     * ------------------------------------------------------------------------
     */
    public static CommercePayments.GatewayNotificationResponse handleAsyncNotificationCallback(
        CommercePayments.PaymentGatewayNotificationContext gatewayNotificationContext,
        String apexName
    ) {
        System.debug('---->Entering AdyenWebhookNotificationHelper.handleAsyncNotificationCallback PaymentGatewayNotificationContext = ' + gatewayNotificationContext);
        CommercePayments.PaymentGatewayNotificationRequest paymentGatewayNotificationRequest = Test.isRunningTest() ? null : gatewayNotificationContext.getPaymentGatewayNotificationRequest();
        CommercePayments.GatewayNotificationResponse gatewayNotificationResponse = new CommercePayments.GatewayNotificationResponse();

        CommercePayments.NotificationSaveResult notificationSaveResult;
        NotificationRequestItem notificationRequestItem = parseAdyenNotificationRequest( paymentGatewayNotificationRequest );

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
                    System.debug('---->Exiting AdyenWebhookNotificationHelper.handleAsyncNotificationCallback after the notification is accepted = ' + gatewayNotificationResponse);
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
            System.debug('---->Exiting AdyenWebhookNotificationHelper.handleAsyncNotificationCallback after identifying that it was the wrong payment adapter = ' + gatewayNotificationResponse);
        }
        return gatewayNotificationResponse;
    }


    /**
     * Take the http request from the async notification callback and deserializes it into AdyenNotificationResponse.
     *
     * @param adyenNotificationRequestPayload   The body of the Adyen notification request.
     * @return AdyenNotificationRequest         The deserialized version of the Adyen nodification request.
     *
     * @see https://docs.adyen.com/development-resources/webhooks/understand-notifications
     */
    public static NotificationRequestItem parseAdyenNotificationRequest(CommercePayments.PaymentGatewayNotificationRequest notificationRequest) {
        String requestBody = Test.isRunningTest() ? TEST_NOTIFICATION_REQUEST_BODY : AdyenPaymentUtility.makeSalesforceCompatible(notificationRequest.getRequestBody().toString());
        AdyenNotification adyenNotification  = (AdyenNotification) JSON.deserialize(requestBody, AdyenNotification.class);
        NotificationRequestItem notificationRequestItem = new NotificationRequestItem();
        if(adyenNotification != null) {
            for(NotificationItems notificationItem : adyenNotification.notificationItems) {
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
    private static CommercePayments.NotificationSaveResult createNotificationSaveResult( NotificationRequestItem notificationRequestItem ) {

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
            System.debug('---> Exiting AdyenWebhookNotificationHelper.createNotificationSaveResult after ignoring unsupported notification = ' + notificationRequestItem.eventCode);
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