public with sharing class AdyenPaymentHelper {

    @TestVisible
    public static String TEST_PAYMENT_METHOD_ID;

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
        Double authAmount = AdyenPaymentUtility.normalizeAmount(authRequest.amount);
        authorizationRequest.amount = new Amount();
        authorizationRequest.amount.currency_x = currencyCode;
        authorizationRequest.amount.value = (authAmount * AdyenPaymentUtility.getAmountMultiplier(currencyCode)).longValue();

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
        authorizationRequest.shopperInteraction = AuthorisationRequest.shopperInteractionEnum.Ecommerce;
        authorizationRequest.shopperReference = UserInfo.getUserId();
        authorizationRequest.applicationInfo = AdyenPaymentUtility.getApplicationInfo(adyenAdapterMdt.System_Integrator_Name__c);
        String body = AdyenPaymentUtility.makeAdyenCompatible(JSON.serialize(authorizationRequest, true));
        AdyenService client = new AdyenService(adyenAdapterMdt);
        client.setEndpoint(adyenAdapterMdt.Authorize_Endpoint__c);
        client.setBody(body);
        HttpResponse response = client.execute();
        return processAuthResponse(response, authAmount, adyenAdapterMdt.Merchant_Account__c);
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

}