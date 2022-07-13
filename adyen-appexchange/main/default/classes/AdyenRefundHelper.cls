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
        // By Default, retrieve the metadata key from the order's sales channel
        String adapterName = payment.OrderPaymentSummary.OrderSummary.SalesChannel.ADYENMERCHANTID__c;

        // Override config for this specific Payment (i.e., a pre-capture) or inherit override from the original PaymentAuthorization
        if (String.isNotBlank(payment.adyenOverrideMerchantConfig__c)) {
            adapterName = payment.adyenOverrideMerchantConfig__c;
        }
        if (String.isNotBlank(payment.PaymentAuthorization?.adyenOverrideMerchantConfig__c)) {
            adapterName = payment.PaymentAuthorization.adyenOverrideMerchantConfig__c;
        }
        if (String.isBlank(adapterName)) {
            adapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        }

        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName);

        String currencyCode = adyenAdapterMdt.Single_Currency_Code__c != null ? adyenAdapterMdt.Single_Currency_Code__c : payment.CurrencyIsoCode.toUppercase();
        String pspReference = (payment.OrderPaymentSummary.FullName == 'DeclineRefund' ? 'dummytransaction' : AdyenPaymentUtility.getRefundGatewayRefNumber(payment));
        ModificationRequest modRequest = AdyenPaymentUtility.createModificationRequest(CommercePayments.RequestType.ReferencedRefund, currencyCode, refundRequest.amount, pspReference, adyenAdapterMdt.Merchant_Account__c);
        modRequest.setApplicationInfo(AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c));
        HttpResponse adyenHttpResponse = AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, adyenAdapterMdt.Refund_Endpoint__c);
        return processRefundResponse(adyenHttpResponse, refundRequest.amount);
    }

    /**
     * @param adyenResponse: Response from Adyen's api after requesting a refund
     * @return CommercePayments.GatewayResponse with populated properties.
    */
    public static CommercePayments.GatewayResponse processRefundResponse(HttpResponse adyenHttpResponse, Double amount) {
        CommercePayments.ReferencedRefundResponse salesforceResponse = new CommercePayments.ReferencedRefundResponse();
        RefundResponse adyenResponse = (RefundResponse)JSON.deserializeStrict(AdyenPaymentUtility.makeSalesforceCompatible(adyenHttpResponse.getBody()), RefundResponse.class);
        salesforceResponse.setAsync(true);
        salesforceResponse.setAmount(amount);
        salesforceResponse.setGatewayDate(System.now());
        salesforceResponse.setGatewayReferenceDetails(adyenResponse.getReference());
        salesforceResponse.setGatewayResultCode(adyenResponse.getStatus());
        salesforceResponse.setGatewayResultCodeDescription(adyenResponse.getMessage());

        if (adyenResponse != null && adyenHttpResponse.getStatusCode() != AdyenConstants.HTTP_ERROR_CODE) { // HTTP connection with Adyen was successful
           salesforceResponse.setGatewayReferenceNumber(adyenResponse.getPSPReference());
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
           if (adyenResponse.getStatus() == AdyenConstants.NOTIFICATION_RECEIVED) {
            salesforceResponse.setGatewayMessage('[refund-received]');
           }
        } else {
           salesforceResponse.setGatewayReferenceNumber(null);
           salesforceResponse.setGatewayMessage(adyenResponse.getMessage());
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SYSTEM_ERROR_SALESFORCE_RESULT_CODE_INFO);
        }
        return salesforceResponse;
    }
}