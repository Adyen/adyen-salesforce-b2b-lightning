public with sharing class AdyenCaptureHelper {

    /**
     * invoked by handleFulfillmentOrderStatusChange to capture funds with Adyen
     * @param captureRequest
     * @return `CommercePayments.GatewayResponse`
     */
    private static CommercePayments.GatewayResponse capture(CommercePayments.CaptureRequest captureRequest) {

        // Retrieve the PaymentAuthorization
        PaymentAuthorization pa = AdyenPaymentUtility.retrievePaymentAuthorization(captureRequest.paymentAuthorizationId);

        String errorMessage = null;
        if(pa == null) errorMessage = 'Payment Authorization Missing';
        if(captureRequest.amount == null) errorMessage = 'Payment Amount Missing';
        String pspReference = AdyenPaymentUtility.getCaptureGatewayRefNumber(pa);
        if(String.isBlank(pspReference)) errorMessage = 'PspReference Missing';
        if(errorMessage != null) throw new AdyenAsyncAdapter.GatewayException(errorMessage);

        // By Default, retrieve the metadata key from the order's sales channel
        String adapterName = String.isNotEmpty(pa.adyenOverrideMerchantConfig__c) ? pa.adyenOverrideMerchantConfig__c : pa.OrderPaymentSummary?.OrderSummary?.SalesChannel?.ADYENMERCHANTID__c;
        String currencyCode = adyenAdapterMdt.Single_Currency_Code__c != null ? adyenAdapterMdt.Single_Currency_Code__c : pa.CurrencyIsoCode;
        Double amount = AdyenPaymentUtility.normalizeAmount(captureRequest.amount);
        ModificationRequest modRequest = AdyenPaymentUtility.createModificationRequest(CommercePayments.RequestType.Capture, adapterName, currencyCode, amount, pspReference);
        if(AdyenPaymentUtility.checkIfKlarnaOrderFromAuthorization(pa)) {
            Map<String, Object> additionalData = AdyenPaymentUtility.getInvoiceData(pa);
            modRequest.additionalData = JSON.serialize(additionalData);
        }
        modRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c);

        ModificationResponse modResponse = AdyenPaymentUtility.getAdyenResponse(CommercePayments.RequestType.Capture, modRequest, adyenAdapterMdt.Capture_Endpoint__c);
        return AdyenPaymentUtility.processAdyensResponse(modResponse, amount, CommercePayments.RequestType.Capture);
    }
}