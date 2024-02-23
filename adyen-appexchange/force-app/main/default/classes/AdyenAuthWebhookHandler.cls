@RestResource(UrlMapping='/authWebhook/v1/*')
global with sharing class AdyenAuthWebhookHandler {
    @HttpPost
    global static String doPost() {
        PaymentAuthorization paymentAuthorization;
        NotificationRequestItem notificationRequestItem;
        RestRequest req = RestContext.request;
        try {
            notificationRequestItem = parseAdyenNotificationRequest(req.requestBody.toString());
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
            String message = 'an exception happened: ' + ex.getMessage() + '. Stack trace: ' + ex.getStackTraceString();
            return insertLogAndReturnResponse(message, paymentAuthorization, notificationRequestItem, req.requestBody.toString(), 'Failed');
        }
    }

    private static NotificationRequestItem parseAdyenNotificationRequest(String requestBody) {
        String requestBodySFCompatible = AdyenPaymentUtility.makeSalesforceCompatible(requestBody);
        AdyenNotification adyenNotification  = (AdyenNotification) JSON.deserialize(requestBodySFCompatible, AdyenNotification.class);
        NotificationRequestItem notificationRequestItem = new NotificationRequestItem();
        for (NotificationItems notificationItem : adyenNotification.notificationItems) {
            if (notificationItem.NotificationRequestItem != null) {
                notificationRequestItem = notificationItem.NotificationRequestItem;
            }
        }
        return notificationRequestItem;
    }

    private static Boolean isValidNotification(NotificationRequestItem notificationRequestItem) {
        return AdyenB2BConstants.NOTIFICATION_REQUEST_TYPE_AUTHORISE.equalsIgnoreCase(notificationRequestItem.eventCode)
                && isValidPspReference(notificationRequestItem.pspReference)
                && isValidId(notificationRequestItem.merchantReference);
    }

    private static Boolean isValidId(String idString) {
        return String.isNotBlank(idString) && idString.isAlphanumeric() && (idString.length() == 15 || idString.length() == 18);
    }

    private static Boolean isValidPspReference(String pspReference) {
        return String.isNotBlank(pspReference) && pspReference.isAlphanumeric() && pspReference.length() == 16;
    }

    private static String handlePaymentAuthorizationFound(PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem, String requestBody) {
        if (isPaymentPending(paymentAuthorization)) {
            updatePaymentAuthorizationStatus(paymentAuthorization, notificationRequestItem);
            return insertLogAndReturnResponse(null, paymentAuthorization, notificationRequestItem, requestBody, 'Success');
        } else {
            return insertLogAndReturnResponse('payment is not pending authorization', paymentAuthorization, notificationRequestItem, requestBody, 'NoOp');
        }
    }

    private static void updatePaymentAuthorizationStatus(PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem) {
        if (Boolean.valueOf(notificationRequestItem.success)) {
            paymentAuthorization.Status = 'Processed';
        } else {
            paymentAuthorization.Status = 'Failed';
        }
        update paymentAuthorization;
    }

    private static Boolean isPaymentPending(PaymentAuthorization paymentAuthorization) {
        return paymentAuthorization.Status.equalsIgnoreCase('Pending');
    }

    private static String handleMissingPaymentAuthorization(NotificationRequestItem notificationRequestItem, String requestBody) {
        WebCart webCart = findWebCart(notificationRequestItem.merchantReference);
        if (webCart == null) {
            return '[accepted] but no payment found for this merchant reference';
        } else {
            return insertLogAndReturnResponse('notification marked to be processed later', null, notificationRequestItem, requestBody, 'Initiated');
        }
    }

    private static PaymentAuthorization findPaymentAuthorization(String pspReference) {
        List<PaymentAuthorization> paymentAuthorizations = [
                SELECT Status, OrderPaymentSummaryId, PaymentGatewayId
                FROM PaymentAuthorization
                WHERE GatewayRefNumber = :pspReference
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

    private static String insertLogAndReturnResponse(String infoMessage, PaymentAuthorization paymentAuthorization, NotificationRequestItem notificationRequestItem, String requestBody, String status) {
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
        paymentGatewayLog.InteractionStatus = status;
        insert paymentGatewayLog;
        return paymentGatewayLog.Response;
    }

    private static String safeCreateGatewayMessage(String message) {
        if (String.isBlank(message)) {
            return '[accepted]';
        }
        String messageWithBut = '[accepted] but ' + message;
        if (messageWithBut.length() > 255) {
            return messageWithBut.substring(0, 255);
        } else {
            return messageWithBut;
        }
    }
}