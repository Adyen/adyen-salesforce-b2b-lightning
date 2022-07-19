public with sharing class AdyenCaptureHelper {

    /**
     * invoked by handleFulfillmentOrderStatusChange to capture funds with Adyen
     * @param captureRequest
     * @return `CommercePayments.GatewayResponse`
     */
    public static CommercePayments.GatewayResponse capture(CommercePayments.CaptureRequest captureRequest) {

        // Retrieve the PaymentAuthorization
        PaymentAuthorization pa = AdyenPaymentUtility.retrievePaymentAuthorization(captureRequest.paymentAuthorizationId);

        String errorMessage = null;
        if(pa == null) {
            errorMessage = 'Payment Authorization Missing';
        }
        if(captureRequest.amount == null) {
            errorMessage = 'Payment Amount Missing';
        }
        String pspReference = AdyenPaymentUtility.getCaptureGatewayRefNumber(pa);
        if(String.isBlank(pspReference)) {
            errorMessage = 'PspReference Missing';
        }
        if(errorMessage != null) {
            throw new AdyenAsyncAdapter.GatewayException(errorMessage);
        }
        String adapterName;
        if (String.isNotBlank(pa.GatewayRefDetails)) {
            adapterName = pa.GatewayRefDetails;
        } else {
            adapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        }
        Adyen_Adapter__mdt adyenAdapterMdt = AdyenPaymentUtility.retrieveGatewayMetadata(adapterName);
        String currencyCode = adyenAdapterMdt.Single_Currency_Code__c != null ? adyenAdapterMdt.Single_Currency_Code__c : pa.CurrencyIsoCode;
        CheckoutModificationRequest modRequest = AdyenPaymentUtility.createModificationRequest(CommercePayments.RequestType.Capture, currencyCode, captureRequest.amount, pspReference, adyenAdapterMdt.Merchant_Account__c);
        String captureEndPointURL = adyenAdapterMdt.Capture_Endpoint__c;
        captureEndPointURL = captureEndPointURL.replace('{paymentPspReference}', pspReference);
        System.debug('captureEndPointURL :: '+ captureEndPointURL);
        HttpResponse adyenHttpResponse = AdyenPaymentUtility.sendModificationRequest(modRequest, adyenAdapterMdt, captureEndPointURL);
        return processCaptureResponse(adyenHttpResponse, captureRequest.amount);
    }

     /**
     * @param adyenResponse: Response from Adyen's api after requesting a capture/refund
     * @return CommercePayments.GatewayResponse with populated properties.
     */
    public static CommercePayments.GatewayResponse processCaptureResponse(HttpResponse adyenHttpResponse, Double amount) {
        CheckoutCaptureResponse adyenResponse = (CheckoutCaptureResponse)JSON.deserializeStrict(AdyenPaymentUtility.makeSalesforceCompatible(adyenHttpResponse.getBody()), CheckoutCaptureResponse.class);
        CommercePayments.CaptureResponse salesforceResponse = new CommercePayments.CaptureResponse();
        salesforceResponse.setAsync(true);
        salesforceResponse.setAmount(amount);
        salesforceResponse.setGatewayDate(System.now());
        salesforceResponse.setGatewayReferenceDetails(adyenResponse.getReference());
        salesforceResponse.setGatewayResultCode(adyenResponse.getStatus());

        if (adyenResponse != null && adyenHttpResponse.getStatusCode() != AdyenConstants.HTTP_ERROR_CODE) { // HTTP connection with Adyen was successful
           salesforceResponse.setGatewayReferenceNumber(adyenResponse.getPSPReference());
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
           if (adyenResponse.getStatus() == AdyenConstants.NOTIFICATION_RECEIVED_CHECKOUT) {
            salesforceResponse.setGatewayMessage('[capture-received]');
           }
        } else {
           salesforceResponse.setGatewayReferenceNumber(null);
           salesforceResponse.setSalesforceResultCodeInfo(AdyenConstants.SYSTEM_ERROR_SALESFORCE_RESULT_CODE_INFO);
        }
        return salesforceResponse;
    }
}