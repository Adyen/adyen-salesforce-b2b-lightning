public with sharing class AdyenDropInController {
    @AuraEnabled(Cacheable=true)
    public static PaymentMethodsAndClientKey fetchPaymentMethods(String adyenAdapterName) {
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(adyenAdapterName);
        PaymentMethodsRequest paymentMethodsRequest = new PaymentMethodsRequest();
        paymentMethodsRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentMethodsRequest.allowedPaymentMethods = new List<String>{AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE};
        paymentMethodsRequest.blockedPaymentMethods = new List<String>{AdyenB2BConstants.BANCONTACT_CARD_PAYMENT_METHOD_TYPE, AdyenB2BConstants.BANCONTACT_MOBILE_PAYMENT_METHOD_TYPE};
        HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payment_Methods_Endpoint__c', JSON.serialize(paymentMethodsRequest));
        PaymentMethodsAndClientKey paymentMethodsAndClientKey = new PaymentMethodsAndClientKey(result.getBody(), adyenAdapter.Client_Key__c);
        return paymentMethodsAndClientKey;
    }

    @AuraEnabled
    public static String makePayment(ClientDetails clientDetails) {
        WebCart cart = fetchCartDetails();
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(clientDetails.adyenAdapterName);
        PaymentsRequest paymentsRequest = buildPaymentsRequest(clientDetails, cart, adyenAdapter);

        HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payments_Endpoint__c', JSON.serialize(paymentsRequest));
        PaymentsResponse paymentsResp = (PaymentsResponse)JSON.deserialize(result.getBody(), PaymentsResponse.class);
        persistPaymentDetails(cart, paymentsResp, clientDetails);

        return JSON.serialize(paymentsResp);
    }

    private static void persistPaymentDetails(WebCart cart, PaymentsResponse paymentsResp, ClientDetails clientDetails) {
        if (String.isBlank(paymentsResp.refusalReason)) {
            ConnectApi.PostAuthorizationResponse postAuthorizationResponse = callPostAuthorize(clientDetails.cardData, cart, paymentsResp);
            if (postAuthorizationResponse.gatewayResponse.gatewayResultCode.equalsIgnoreCase('success')) {
                updateCartDetails(postAuthorizationResponse, cart, clientDetails.getCompatibleBillingAddress());
            } else {
                throw new AuraHandledException('Could not update cart with payment! Error: ' + JSON.serialize(postAuthorizationResponse.gatewayResponse));
            }
        }
    }

    @AuraEnabled
    public static String makeDetailsCall(Object stateData, String adyenAdapterName) {
        System.debug(JSON.serialize(stateData));
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(adyenAdapterName);
        HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payments_Details_Endpoint__c', JSON.serialize(stateData));
        PaymentsResponse paymentsResp = (PaymentsResponse)JSON.deserialize(result.getBody(), PaymentsResponse.class);
        if (paymentsResp.resultCode == PaymentsResponse.ResultCodeEnum.AUTHORISED) {
            persistPspReference(paymentsResp.merchantReference, paymentsResp.pspReference);
        }
        return JSON.serialize(paymentsResp);
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
    private static PaymentsRequest buildPaymentsRequest(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        Amount requestAmount = new Amount();
        requestAmount.value = (cart.GrandTotalAmount * AdyenPaymentUtility.getAmountMultiplier(cart.CurrencyIsoCode)).longValue();
        requestAmount.currency_x = cart.CurrencyIsoCode;

        PaymentsRequest paymentsRequest = new PaymentsRequest();
        paymentsRequest.paymentMethod = clientDetails.getPaymentMethodDetails();
        paymentsRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentsRequest.amount = requestAmount;
        paymentsRequest.reference = cart.Id;
        paymentsRequest.shopperReference = cart.OwnerId;
        paymentsRequest.shopperEmail = UserInfo.getUserEmail();
        paymentsRequest.returnUrl = AdyenB2BUtils.getSiteCheckoutUrl(clientDetails.urlPath);
        paymentsRequest.billingAddress = clientDetails.getCompatibleBillingAddress();
        paymentsRequest.browserInfo = clientDetails.getBrowserInfo();
        paymentsRequest.applicationInfo = AdyenB2BUtils.getApplicationInfo(adyenAdapter.System_Integrator_Name__c);
        paymentsRequest.channel = 'Web';
        paymentsRequest.origin = Url.getOrgDomainUrl().toExternalForm();
        return paymentsRequest;
    }

    private static ConnectApi.PostAuthorizationResponse callPostAuthorize(ClientDetails.CardData cardData, WebCart webCart, PaymentsResponse paymentsResp) {
        ConnectApi.PostAuthRequest postAuthRequest = new ConnectApi.PostAuthRequest();
        postAuthRequest.accountId = webCart.AccountId;
        postAuthRequest.amount = webCart.GrandTotalAmount;
        postAuthRequest.currencyIsoCode = webCart.CurrencyIsoCode;
        postAuthRequest.effectiveDate = System.now();
        postAuthRequest.paymentGatewayId = AdyenB2BUtils.fetchAdyenGatewayId();
        postAuthRequest.paymentMethod = new ConnectApi.PostAuthApiPaymentMethodRequest();
        postAuthRequest.paymentMethod.cardPaymentMethod = createCardPayMethodRequest(cardData);
        postAuthRequest.paymentMethod.cardPaymentMethod.accountId = webCart.AccountId;
        postAuthRequest.paymentGroup = new ConnectApi.PaymentGroupRequest();
        postAuthRequest.paymentGroup.createPaymentGroup = true;
        postAuthRequest.paymentGroup.currencyIsoCode = webCart.CurrencyIsoCode;

        Map<String,String> additionalData = new Map<String,String>();
        additionalData.put('pspReference', paymentsResp.pspReference);
        additionalData.put('isAsync', String.valueOf(paymentsResp.resultCode != PaymentsResponse.ResultCodeEnum.AUTHORISED));
        postAuthRequest.additionalData = additionalData;

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

    private static ConnectApi.CardPaymentMethodRequest createCardPayMethodRequest(ClientDetails.CardData cardData) {
        ConnectApi.CardPaymentMethodRequest cardPaymentMethodRequest = new ConnectApi.CardPaymentMethodRequest();
        cardPaymentMethodRequest.cardHolderName = cardData.holderName;
        cardPaymentMethodRequest.cardType = cardData.getBrandSFCompatible();
        cardPaymentMethodRequest.cardNumber = cardData.fakeFullCardNumber();
        return cardPaymentMethodRequest;
    }

    private static void updateCartDetails(ConnectApi.PostAuthorizationResponse postAuthorizationResponse, WebCart webCart, Address billingAddress) {
        webCart.PaymentGroupId = postAuthorizationResponse.paymentGroup.id;
        webCart.PaymentMethodId = postAuthorizationResponse.paymentMethod.id;
        webCart.BillingCity = billingAddress.city;
        webCart.BillingCountry = billingAddress.country;
        webCart.BillingPostalCode = billingAddress.postalCode;
        webCart.BillingStreet = billingAddress.street;
        update webCart;
    }

    private static void persistPspReference(Id cartId, String pspReference) {
        Id paymentMethodId = [SELECT PaymentMethodId FROM WebCart WHERE Id = :cartId].PaymentMethodId;
        PaymentAuthorization paymentAuthorization = [SELECT GatewayRefNumber FROM PaymentAuthorization WHERE PaymentMethodId = :paymentMethodId];
        paymentAuthorization.GatewayRefNumber = pspReference;
        update paymentAuthorization;
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
}