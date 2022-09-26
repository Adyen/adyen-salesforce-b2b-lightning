public with sharing class AdyenRefundHelper {

    /**
     * Calls the Service to post a REFUND to Adyen. Evaluates the response wrapped in custom class Adyen and sets appropriate
     * properties on CommercePayments.ReferenceRefundResponse.
     *
     *
     * @param refundRequest   The CommercePayments.ReferencedRefundRequest Object.
     * @return refundResponse  The CommercePayments.ReferencedRefundResponse Object.
     *
     * @see AdyenService
    */
    public static CommercePayments.GatewayResponse refund(CommercePayments.ReferencedRefundRequest refundRequest) {

        // Retrieve the Payment
        Payment payment = AdyenPaymentUtility.retrievePayment(refundRequest.PaymentId);
        String adapterName = payment?.PaymentAuthorization?.GatewayRefDetails;
        String errorMessage = null;
        if(payment == null) {
            errorMessage = 'Payment Info Missing';
        }
        if(refundRequest.amount == null) {
            errorMessage = 'Payment Amount Missing';
        }
        if(errorMessage != null) {
            throw new AdyenAsyncAdapter.GatewayException(errorMessage);
        }
        if (String.isBlank(adapterName)) {
            adapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        }
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName);

        String currencyCode = adyenAdapterMdt.Single_Currency_Code__c != null ? adyenAdapterMdt.Single_Currency_Code__c : payment.CurrencyIsoCode.toUppercase();
        String pspReference = (payment.OrderPaymentSummary.FullName == 'DeclineRefund' ? 'dummytransaction' : AdyenPaymentUtility.getRefundGatewayRefNumber(payment));
        CheckoutModificationRequest modRequest = AdyenPaymentUtility.createModificationRequest(CommercePayments.RequestType.ReferencedRefund, currencyCode, refundRequest.amount, pspReference, adyenAdapterMdt.Merchant_Account__c);
        String refundEndPointURL = adyenAdapterMdt.Refund_Endpoint__c;
        refundEndPointURL = refundEndPointURL.replace('{paymentPspReference}', pspReference);
        HttpResponse adyenHttpResponse = AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, refundEndPointURL);
        return processRefundResponse(adyenHttpResponse, refundRequest.amount);
    }

    /**
     * @param adyenResponse: Response from Adyen's api after requesting a refund
     * @return CommercePayments.GatewayResponse with populated properties.
    */
    public static CommercePayments.GatewayResponse processRefundResponse(HttpResponse adyenHttpResponse, Double amount) {
        CommercePayments.ReferencedRefundResponse salesforceResponse = new CommercePayments.ReferencedRefundResponse();
        CheckoutRefundResponse adyenResponse = (CheckoutRefundResponse)JSON.deserializeStrict(AdyenPaymentUtility.makeSalesforceCompatible(adyenHttpResponse.getBody()), CheckoutRefundResponse.class);
        salesforceResponse.setAsync(true);
        salesforceResponse.setAmount(amount);
        salesforceResponse.setGatewayDate(System.now());
        salesforceResponse.setGatewayReferenceDetails(adyenResponse.getReference());
        salesforceResponse.setGatewayResultCode(adyenResponse.getStatus());

        if (adyenResponse != null && adyenHttpResponse.getStatusCode() != AdyenConstants.HTTP_ERROR_CODE) { // HTTP connection with Adyen was successful
           salesforceResponse.setGatewayReferenceNumber(adyenResponse.getPSPReference());
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
           if (adyenResponse.getStatus() == AdyenConstants.NOTIFICATION_RECEIVED_CHECKOUT) {
            salesforceResponse.setGatewayMessage('[refund-received]');
           }
        } else {
           salesforceResponse.setGatewayReferenceNumber(null);
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SYSTEM_ERROR_SALESFORCE_RESULT_CODE_INFO);
        }
        return salesforceResponse;
    }
}