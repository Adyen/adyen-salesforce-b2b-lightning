public with sharing class AdyenPaymentHelper {
     /**
     *  Receives Payment Gateway Context from AdyenAsyncAdapter, looks at the context type and then invokes the appropriate Capture or Refund operation
     * 
     * @param PaymentGatewayContext from Salesforce
     * @return `CommercePayments.GatewayResponse`
     */
    public static CommercePayments.GatewayResponse handleFulfillmentOrderStatusChange(CommercePayments.PaymentGatewayContext paymentGatewayContext){
        CommercePayments.RequestType paymentRequestType = paymentGatewayContext.getPaymentRequestType();
        CommercePayments.PaymentGatewayRequest paymentRequest = paymentGatewayContext.getPaymentRequest();
        try {
            if (paymentRequestType == CommercePayments.RequestType.PostAuth) {
                return createPostAuthResponse((CommercePayments.PostAuthorizationRequest) paymentRequest);
            } else {
                return null;
            }
        } catch (Exception ex) {
            return new CommercePayments.GatewayErrorResponse(String.valueOf(AdyenConstants.HTTP_ERROR_CODE), ex.getMessage());
        }
    }

    public static CommercePayments.GatewayResponse createPostAuthResponse(CommercePayments.PostAuthorizationRequest postAuthRequest) {
        CommercePayments.PostAuthorizationResponse postAuthorizationResponse = new CommercePayments.PostAuthorizationResponse();
        String pspReference = postAuthRequest.additionalData?.get('pspReference');
        if (pspReference == null) {
            pspReference = getRandomNumber(16);
        }

        if (postAuthRequest.amount != null) {
            postAuthorizationResponse.setAmount(postAuthRequest.amount);
        }
        postAuthorizationResponse.setGatewayResultCode('success');
        postAuthorizationResponse.setGatewayResultCodeDescription('Transaction Normal');
        postAuthorizationResponse.setGatewayReferenceNumber(pspReference);
        postAuthorizationResponse.setSalesforceResultCodeInfo(AdyenConstants.SUCCESS_SALESFORCE_RESULT_CODE_INFO);
        postAuthorizationResponse.setGatewayDate(System.now());
        postAuthorizationResponse.setAsync(true);

        return postAuthorizationResponse;
    }

    private static String getRandomNumber(Integer stringLength){
        final Integer max = Integer.valueOf(Math.pow(10,stringLength) - 1);
        return String.valueOf(Math.round(Math.random() * max)).leftPad(stringLength,'0');
    }
}