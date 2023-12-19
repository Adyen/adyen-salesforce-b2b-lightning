public with sharing class AdyenDropInController {
    @AuraEnabled(Cacheable=true)
    public static PaymentMethodsAndClientKey fetchPaymentMethods(String adyenAdapterName) {
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(adyenAdapterName);
        PaymentMethodsRequest paymentMethodsRequest = new PaymentMethodsRequest();
        paymentMethodsRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentMethodsRequest.allowedPaymentMethods = new List<String>{AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE};
        paymentMethodsRequest.blockedPaymentMethods = new List<String>{'bcmc', 'bcmc_mobile'};
        HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payment_Methods_Endpoint__c', JSON.serialize(paymentMethodsRequest));
        PaymentMethodsAndClientKey paymentMethodsAndClientKey = new PaymentMethodsAndClientKey(result.getBody(), adyenAdapter.Client_Key__c);
        return paymentMethodsAndClientKey;
    }

    @AuraEnabled
    public static Boolean makePayment(String paymentMethodType, String paymentMethod, String adyenAdapterName, String endDigits) {
        WebCart cart = fetchCartDetails();
        PaymentMethodDetails paymentMethodDetails = deserializePaymentMethod(paymentMethodType, paymentMethod);
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(adyenAdapterName);
        PaymentsRequest paymentsRequest = buildPaymentsRequest(paymentMethodDetails, cart, adyenAdapter);

        HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payments_Endpoint__c', JSON.serialize(paymentsRequest));
        PaymentsResponse paymentsResp = (PaymentsResponse)JSON.deserialize(result.getBody(), PaymentsResponse.class);
        if (paymentsResp.resultCode != PaymentsResponse.ResultCodeEnum.AUTHORISED) {
            return false;
        } else {
            RequiredCardDetails requiredCardDetails = new RequiredCardDetails(
                cart.AccountId,
                paymentsResp.additionalData.get('cardBin'),
                endDigits,
                paymentsResp.additionalData.get('paymentMethodVariant'),
                ((CardDetails)paymentMethodDetails).holderName
            );
            ConnectApi.PostAuthorizationResponse postAuthorizationResponse = callPostAuthorize(requiredCardDetails, cart, paymentsResp.pspReference);
            if (postAuthorizationResponse.gatewayResponse.gatewayResultCode.equalsIgnoreCase('success')) {
                updateCartWithPaymentMethod(postAuthorizationResponse, cart);
                return true;
            }
            return false;
        }
    }

    @TestVisible
    private static PaymentMethodDetails deserializePaymentMethod(String paymentMethodType, String paymentMethod) {
        try {
            if (paymentMethodType.equalsIgnoreCase(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE)) {
                return (CardDetails)JSON.deserialize(paymentMethod, CardDetails.class);
            } else {
                throw new AuraHandledException('Unhandled payment method of type: ' + paymentMethodType);
            }
        } catch (Exception ex) {
            throw new AuraHandledException('Error deserializing payment method: ' + ex.getMessage());
        }
    }

    private static WebCart fetchCartDetails() {
        try {
            return [
                SELECT GrandTotalAmount, CurrencyIsoCode, Owner.Name, AccountId
                FROM WebCart
                WHERE OwnerId = :UserInfo.getUserId() AND Status = 'Checkout'
                WITH SECURITY_ENFORCED
            ];
        } catch (Exception ex) {
            throw new AuraHandledException('Could not fetch cart information, error: ' + ex.getMessage());
        }
    }

    @TestVisible
    private static PaymentsRequest buildPaymentsRequest(PaymentMethodDetails paymentMethodDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        Amount requestAmount = new Amount();
        requestAmount.value = (cart.GrandTotalAmount * AdyenPaymentUtility.getAmountMultiplier(cart.CurrencyIsoCode)).longValue();
        requestAmount.currency_x = cart.CurrencyIsoCode;

        PaymentsRequest paymentsRequest = new PaymentsRequest();
        paymentsRequest.paymentMethod = paymentMethodDetails;
        paymentsRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentsRequest.amount = requestAmount;
        paymentsRequest.reference = cart.Id;
        paymentsRequest.shopperReference = cart.OwnerId;
        paymentsRequest.returnUrl = Url.getOrgDomainUrl().toExternalForm();
        paymentsRequest.applicationInfo = AdyenB2BUtils.getApplicationInfo(adyenAdapter.System_Integrator_Name__c);
        return paymentsRequest;
    }

    private static ConnectApi.PostAuthorizationResponse callPostAuthorize(RequiredCardDetails requiredCardDetails, WebCart webCart, String pspReference) {
        ConnectApi.PostAuthRequest postAuthRequest = new ConnectApi.PostAuthRequest();
        postAuthRequest.accountId = webCart.AccountId;
        postAuthRequest.amount = webCart.GrandTotalAmount;
        postAuthRequest.currencyIsoCode = webCart.CurrencyIsoCode;
        postAuthRequest.effectiveDate = System.now();
        postAuthRequest.paymentGatewayId = AdyenB2BUtils.fetchAdyenGatewayId();
        postAuthRequest.paymentMethod = new ConnectApi.PostAuthApiPaymentMethodRequest();
        postAuthRequest.paymentMethod.cardPaymentMethod = createCardPayMethodRequest(requiredCardDetails);
        postAuthRequest.paymentGroup = new ConnectApi.PaymentGroupRequest();
        postAuthRequest.paymentGroup.createPaymentGroup = true;
        postAuthRequest.paymentGroup.currencyIsoCode = webCart.CurrencyIsoCode;
        postAuthRequest.comments = pspReference;
        ConnectApi.PostAuthorizationResponse postAuthorizationResponse = Test.isRunningTest() ? mockPostAuthResponse() : ConnectApi.Payments.postAuth(postAuthRequest);
        return postAuthorizationResponse;
    }

    @TestVisible
    private static ConnectApi.PostAuthorizationResponse mockPostAuthResponse() {
        ConnectApi.PostAuthorizationResponse postAuthorizationResponse = new ConnectApi.PostAuthorizationResponse();
        postAuthorizationResponse.gatewayResponse = new ConnectApi.PostAuthGatewayResponse();
        postAuthorizationResponse.gatewayResponse.gatewayResultCode = 'success';
        postAuthorizationResponse.paymentGroup = new ConnectApi.PaymentGroupResponse();
        postAuthorizationResponse.paymentMethod = new ConnectApi.PaymentMethodResponse();
        return postAuthorizationResponse;
    }

    private static ConnectApi.CardPaymentMethodRequest createCardPayMethodRequest(RequiredCardDetails requiredCardDetails) {
        ConnectApi.CardPaymentMethodRequest cardPaymentMethodRequest = new ConnectApi.CardPaymentMethodRequest();
        cardPaymentMethodRequest.accountId = requiredCardDetails.accountId;
        cardPaymentMethodRequest.cardHolderName = requiredCardDetails.holderName;
        cardPaymentMethodRequest.cardType = AdyenB2BUtils.makeSalesforceCompatible(requiredCardDetails.cardType);
        cardPaymentMethodRequest.cardNumber = requiredCardDetails.fakeFullCardNumber();
        return cardPaymentMethodRequest;
    }

    private static void updateCartWithPaymentMethod(ConnectApi.PostAuthorizationResponse postAuthorizationResponse, WebCart webCart) {
        webCart.PaymentGroupId = postAuthorizationResponse.paymentGroup.id;
        webCart.PaymentMethodId = postAuthorizationResponse.paymentMethod.id;
        update webCart;
    }


    public class PaymentMethodsAndClientKey {
        @AuraEnabled
        public String paymentMethodsResponse;
        @AuraEnabled
        public String clientKey;

        PaymentMethodsAndClientKey(String paymentMethodsResponse, String clientKey) {
            this.paymentMethodsResponse = paymentMethodsResponse;
            this.clientKey = clientKey;
        }
    }

    private class RequiredCardDetails {
        public String accountId;
        public String cardBin;
        public String lastFourDigits;
        public String cardType;
        public String holderName;

        public String fakeFullCardNumber() {
            return cardBin + '000000' + lastFourDigits;
        }

        public RequiredCardDetails(Id accountId, String cardBin, String lastFour, String cardType, String holderName) {
            this.accountId = accountId;
            this.cardBin = cardBin;
            this.lastFourDigits = lastFour;
            this.cardType = cardType;
            this.holderName = holderName;
        }
    }
}