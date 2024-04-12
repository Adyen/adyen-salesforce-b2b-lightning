public with sharing class AdyenDropInController {
    public class CriticalException extends Exception {}

    @AuraEnabled
    public static PaymentMethodsAndClientKey fetchPaymentMethods(String adyenAdapterName) {
        WebCart cart;
        try {
            Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(adyenAdapterName);
            cart = AdyenB2BUtils.fetchCartDetails();
            Amount requestAmount = new Amount();
            requestAmount.value = (cart.GrandTotalAmount * AdyenB2BUtils.getAmountMultiplier(cart.CurrencyIsoCode)).round(System.RoundingMode.HALF_UP);
            requestAmount.currency_x = cart.CurrencyIsoCode;
            String shopperLocale = UserInfo.getLocale();
            String[] localeParts = shopperLocale.split('_');
            String countryCode = localeParts.size() > 1 ? localeParts[1] : '';

            PaymentMethodsRequest paymentMethodsRequest = new PaymentMethodsRequest();
            paymentMethodsRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
            paymentMethodsRequest.amount = requestAmount;
            paymentMethodsRequest.allowedPaymentMethods = new List<String>{AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE};
            paymentMethodsRequest.blockedPaymentMethods = new List<String>{AdyenB2BConstants.BANCONTACT_CARD_PAYMENT_METHOD_TYPE, AdyenB2BConstants.BANCONTACT_MOBILE_PAYMENT_METHOD_TYPE};
            paymentMethodsRequest.shopperLocale = shopperLocale;
            paymentMethodsRequest.countryCode = countryCode;

            HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payment_Methods_Endpoint__c', JSON.serialize(paymentMethodsRequest));
            PaymentMethodsAndClientKey paymentMethodsAndClientKey = new PaymentMethodsAndClientKey(result.getBody(), adyenAdapter.Client_Key__c);
            return paymentMethodsAndClientKey;
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, ex.getMessage());
            LogEntry.insertLogException(ex, 'Fetch Payment Method Error', AdyenDropInController.class.getName(), 'fetchPaymentMethods');
            return null;
        }
    }

    @AuraEnabled
    public static MinimalPaymentResponse makePayment(ClientDetails clientDetails) {
        WebCart cart;
        try {
            cart = AdyenB2BUtils.fetchCartDetails();
            Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(clientDetails.adyenAdapterName);
            PaymentsRequest paymentsRequest = buildPaymentsRequest(clientDetails, cart, adyenAdapter);

            HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payments_Endpoint__c', JSON.serialize(paymentsRequest));
            PaymentsResponse paymentsResp = (PaymentsResponse)JSON.deserialize(result.getBody(), PaymentsResponse.class);
            persistPaymentDetails(cart, paymentsResp, clientDetails);

            return new MinimalPaymentResponse(paymentsResp);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, ex.getMessage());
            LogEntry.insertLogException(ex, 'Make Payment Error', AdyenDropInController.class.getName(), 'makePayment', cart?.Id);
            return null;
        }
    }

    @AuraEnabled
    public static MinimalPaymentResponse makeDetailsCall(Object stateData, String adyenAdapterName) {
        PaymentsResponse paymentsResp;
        try {
            Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(adyenAdapterName);
            HttpResponse result = AdyenB2BUtils.makePostRequest(adyenAdapter, 'Payments_Details_Endpoint__c', JSON.serialize(stateData));
            paymentsResp = (PaymentsResponse)JSON.deserialize(result.getBody(), PaymentsResponse.class);
            if (AdyenB2BUtils.isPaymentAccepted(paymentsResp.resultCode)) {
                persistPspReference(paymentsResp.merchantReference, paymentsResp.pspReference);
            } else if (paymentsResp.action == null) {
                handleFailedPaymentAttempt(paymentsResp, paymentsResp.merchantReference);
            }
            return new MinimalPaymentResponse(paymentsResp);
        } catch (Exception ex) {
            System.debug(LoggingLevel.ERROR, ex.getMessage());
            LogEntry.insertLogException(ex, 'Action Payment Error', AdyenDropInController.class.getName(), 'makeDetailsCall', paymentsResp.merchantReference);
            return null;
        }
    }

    private static void persistPaymentDetails(WebCart cart, PaymentsResponse paymentsResp, ClientDetails clientDetails) {
        if (AdyenB2BUtils.isPaymentAccepted(paymentsResp.resultCode) || paymentsResp.action != null) {
            ConnectApi.PostAuthorizationResponse postAuthorizationResponse = callPostAuthorize(clientDetails.cardData, cart, paymentsResp);
            if (postAuthorizationResponse.gatewayResponse.gatewayResultCode.equalsIgnoreCase('success')) {
                updateCartDetails(postAuthorizationResponse, cart, clientDetails.getCompatibleBillingAddress());
            } else {
                throw new CriticalException('Post authorize payment denied! Gateway response: ' + JSON.serialize(postAuthorizationResponse.gatewayResponse));
            }
        } else {
            handleFailedPaymentAttempt(paymentsResp, cart.Id);
        }
    }



    @TestVisible
    private static PaymentsRequest buildPaymentsRequest(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        Amount requestAmount = new Amount();
        requestAmount.value = (cart.GrandTotalAmount * AdyenB2BUtils.getAmountMultiplier(cart.CurrencyIsoCode)).round(System.RoundingMode.HALF_UP);
        requestAmount.currency_x = cart.CurrencyIsoCode;

        PaymentsRequest paymentsRequest = new PaymentsRequest();
        paymentsRequest.paymentMethod = clientDetails.getPaymentMethodDetails();
        paymentsRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentsRequest.amount = requestAmount;
        paymentsRequest.reference = cart.Id;
        paymentsRequest.shopperReference = cart.OwnerId;
        paymentsRequest.shopperEmail = UserInfo.getUserEmail();
        paymentsRequest.returnUrl = AdyenB2BUtils.getSiteUrl() + '/payment-processing';
        paymentsRequest.billingAddress = clientDetails.getCompatibleBillingAddress();
        paymentsRequest.browserInfo = clientDetails.getBrowserInfo();
        paymentsRequest.applicationInfo = AdyenB2BUtils.getApplicationInfo(adyenAdapter.System_Integrator_Name__c);
        paymentsRequest.channel = 'Web';
        paymentsRequest.origin = AdyenB2BUtils.getSiteUrl();

        paymentsRequest.authenticationData = new AuthenticationData();
        paymentsRequest.authenticationData.threeDSRequestData = new ThreeDSRequestData();
        paymentsRequest.authenticationData.threeDSRequestData.nativeThreeDS = 'preferred';

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
        try {
            webCart.PaymentGroupId = postAuthorizationResponse.paymentGroup.id;
            webCart.PaymentMethodId = postAuthorizationResponse.paymentMethod.id;
            webCart.BillingCity = billingAddress.city;
            webCart.BillingCountry = billingAddress.country;
            webCart.BillingPostalCode = billingAddress.postalCode;
            webCart.BillingStreet = billingAddress.street;
            update webCart;
        } catch (Exception ex) {
            throw new CriticalException('Failed to update cart details, error: ' + ex.getMessage());
        }
    }

    private static void persistPspReference(Id cartId, String pspReference) {
        try {
            Id paymentMethodId = [SELECT PaymentMethodId FROM WebCart WHERE Id = :cartId].PaymentMethodId;
            PaymentAuthorization paymentAuthorization = [SELECT GatewayRefNumber FROM PaymentAuthorization WHERE PaymentMethodId = :paymentMethodId];
            paymentAuthorization.GatewayRefNumber = pspReference;
            update paymentAuthorization;
        } catch (Exception ex) {
            throw new CriticalException('Failed to persist psp reference, error: ' + ex.getMessage());
        }
    }

    public static void handleFailedPaymentAttempt(PaymentsResponse paymentsResp, Id cartId) {
        String details = String.format('PSP Reference: {0}\nResult Code: {1}\nRefusal Reason: {2}',new List<String>{paymentsResp.pspReference, paymentsResp.resultCode.name(), paymentsResp.refusalReason});
        LogEntry.insertLogInformation('Failed Payment Attempt', cartId, 'The payment failed with code: ' + paymentsResp.resultCode.name(), details);
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

    public class MinimalPaymentResponse {
        @AuraEnabled
        public Boolean paymentSuccessful;
        @AuraEnabled
        public String action;

        public MinimalPaymentResponse(PaymentsResponse paymentsResponse) {
            if (paymentsResponse.action != null) {
                this.action = JSON.serialize(paymentsResponse.action);
            }
            this.paymentSuccessful = AdyenB2BUtils.isPaymentAccepted(paymentsResponse.resultCode);
        }
    }
}