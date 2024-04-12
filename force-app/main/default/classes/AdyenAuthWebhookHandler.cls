@RestResource(UrlMapping='/authWebhook/v1/*')
global without sharing class AdyenAuthWebhookHandler {
    @HttpPost
    global static String doPost() {
        PaymentAuthorization paymentAuthorization;
        NotificationRequestItem notificationRequestItem;
        RestRequest req = RestContext.request;
        try {
            HMACValidator validator = new HMACValidator();
            Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
            notificationRequestItem = parseAdyenNotificationRequest(req.requestBody.toString());
            if (!Test.isRunningTest() && !validator.validateHMAC(notificationRequestItem, adyenAdapter.HMAC_Key__c)){
                return '[accepted] but not valid notification request';
            }
            if (!isValidNotification(notificationRequestItem)) {
                return '[accepted] but unsupported notification type or empty reference ';
            }
            paymentAuthorization = findPaymentAuthorization(notificationRequestItem.pspReference);
            if (paymentAuthorization != null) {
                return handlePaymentAuthorizationFound(paymentAuthorization, notificationRequestItem, req.requestBody.toString());
            } else {
                return handleMissingPaymentAuthorization(notificationRequestItem, req.requestBody.toString());
            }
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, ex.getMessage());
            if (ex instanceof HMACValidator.HmacValidationException){
                return '[accepted] but not valid notification request';
            } else {
                LogEntry.insertLogException(ex, 'Adyen Auth Web Hook Handler Error', AdyenAuthWebhookHandler.class.getName(), 'doPost', req.requestBody?.toString());
                return '[accepted] but an exception happened';
            }
        }
    }

    private static NotificationRequestItem parseAdyenNotificationRequest(String requestBody) {
        String requestBodySFCompatible = AdyenB2BUtils.makeSalesforceCompatible(requestBody);
        AdyenNotification adyenNotification  = (AdyenNotification)JSON.deserialize(requestBodySFCompatible, AdyenNotification.class);
        NotificationRequestItem notificationRequestItem = adyenNotification.notificationItems[0].NotificationRequestItem;
        return notificationRequestItem;
    }

    private static Boolean isValidNotification(NotificationRequestItem notificationRequestItem) {
        return AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE.equalsIgnoreCase(notificationRequestItem.eventCode)
                && isValidPspReference(notificationRequestItem.pspReference)
                && isValidId(notificationRequestItem.merchantReference);
    }

    // Salesforce Ids are alphanumeric values containing 15 (case sensitive) or 18 characters (case insensitive)
    private static Boolean isValidId(String idString) {
        return String.isNotBlank(idString) && idString.isAlphanumeric() && (idString.length() == 15 || idString.length() == 18);
    }

    // The PSP Reference number is a alphanumeric value containing 16 characters (https://help.adyen.com/en_US/knowledge/payments/payment-basics/what-is-a-psp-reference-number)
    private static Boolean isValidPspReference(String pspReference) {
        return String.isNotBlank(pspReference) && pspReference.isAlphanumeric() && pspReference.length() == 16;
    }

    private static String handlePaymentAuthorizationFound(PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem, String requestBody) {
        if (isPaymentPending(paymentAuthorization)) {
            updatePaymentAuthorizationStatus(paymentAuthorization, notificationRequestItem);
            return insertLogAndReturnResponse(null, paymentAuthorization, notificationRequestItem, requestBody, AdyenB2BConstants.PaymentGatewayLogStatus.SUCCESS);
        } else {
            return '[accepted] but payment is not pending authorization';
        }
    }

    private static void updatePaymentAuthorizationStatus(PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem) {
        if (Boolean.valueOf(notificationRequestItem.success)) {
            paymentAuthorization.Status = AdyenB2BConstants.PaymentAuthorizationStatus.PROCESSED.name();
        } else {
            paymentAuthorization.Status = AdyenB2BConstants.PaymentAuthorizationStatus.FAILED.name();
        }
        update paymentAuthorization;
    }

    private static Boolean isPaymentPending(PaymentAuthorization paymentAuthorization) {
        return paymentAuthorization.Status.equalsIgnoreCase('Pending');
    }

    private static String handleMissingPaymentAuthorization(NotificationRequestItem notificationRequestItem, String requestBody) {
        WebCart webCart = findWebCart(notificationRequestItem.merchantReference);
        if (webCart == null) {
            return '[accepted] but no cart found for this merchant reference';
        } else {
            return insertLogAndReturnResponse('notification marked to be processed later', null, notificationRequestItem, requestBody, AdyenB2BConstants.PaymentGatewayLogStatus.INITIATED);
        }
    }

    private static PaymentAuthorization findPaymentAuthorization(String pspReference) {
        List<PaymentAuthorization> paymentAuthorizations = [
            SELECT Status, OrderPaymentSummaryId, PaymentGatewayId
            FROM PaymentAuthorization
            WHERE GatewayRefNumber = :pspReference AND OrderPaymentSummaryId != NULL
            LIMIT 1
        ];
        return paymentAuthorizations.isEmpty() ? null : paymentAuthorizations[0];
    }

    private static WebCart findWebCart(Id webCartId) {
        List<WebCart> webCarts = [
            SELECT Id
            FROM WebCart
            WHERE Id = :webCartId
            LIMIT 1
        ];
        return webCarts.isEmpty() ? null : webCarts[0];
    }

    private static String insertLogAndReturnResponse(String infoMessage, PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem, String requestBody, AdyenB2BConstants.PaymentGatewayLogStatus status) {
        PaymentGatewayLog paymentGatewayLog = new PaymentGatewayLog();
        paymentGatewayLog.IsNotification = 'Yes';
        paymentGatewayLog.ReferencedEntityId = paymentAuthorization?.Id;
        paymentGatewayLog.OrderPaymentSummaryId = paymentAuthorization?.OrderPaymentSummaryId;
        paymentGatewayLog.PaymentGatewayId = paymentAuthorization?.PaymentGatewayId;
        paymentGatewayLog.GatewayRefNumber = notificationRequestItem?.pspReference;
        paymentGatewayLog.CurrencyIsoCode = notificationRequestItem?.amount.currency_x;
        paymentGatewayLog.GatewayResultCode = notificationRequestItem?.success;
        paymentGatewayLog.GatewayResultCodeDescription = notificationRequestItem?.reason;
        paymentGatewayLog.Request = requestBody;
        paymentGatewayLog.GatewayMessage = safeCreateGatewayMessage(infoMessage);
        paymentGatewayLog.Response = paymentGatewayLog.GatewayMessage;
        paymentGatewayLog.InteractionType = 'Authorization';
        paymentGatewayLog.InteractionStatus = status.name();
        insert paymentGatewayLog;
        return paymentGatewayLog.Response;
    }

    private static String safeCreateGatewayMessage(String message) {
        if (String.isBlank(message)) {
            return '[accepted]';
        }
        String messageWithBut = '[accepted] but ' + message;
        return AdyenB2BUtils.safeAssignTextFieldValue(messageWithBut, PaymentGatewayLog.GatewayMessage.getDescribe());
    }
}