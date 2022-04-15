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
    private static CommercePayments.GatewayResponse refund(CommercePayments.ReferencedRefund refundRequest) {

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
        ModificationRequest modRequest = AdyenPaymentUtility.createModificationRequest(CommercePayments.RequestType.ReferencedRefund, currencyCode, refundRequest.amount, pspReference);
        modRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c);

        ModificationResponse modResponse = AdyenPaymentUtility.sendModificationRequest(CommercePayments.RequestType.ReferencedRefund, modRequest, adyenAdapterMdt.Refund_Endpoint__c);
        return AdyenPaymentUtility.processAdyenResponse(modResponse, refundRequest.amount, CommercePayments.RequestType.ReferencedRefund);
    }
}