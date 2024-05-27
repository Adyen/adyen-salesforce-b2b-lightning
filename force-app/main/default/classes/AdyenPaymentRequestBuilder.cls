public with sharing class AdyenPaymentRequestBuilder {
    public static PaymentsRequest create(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        PaymentMethodDetails paymentMethodDetails = clientDetails.getPaymentMethodDetails();
        if (paymentMethodDetails instanceof CardDetails) {
            return buildCardPaymentRequest(clientDetails, cart, adyenAdapter);
        } else if (paymentMethodDetails instanceof SepaDirectDebitDetails || paymentMethodDetails instanceof ACHDetails) {
            return buildCommonPaymentsRequest(clientDetails, cart, adyenAdapter);
        } else {
            throw new AdyenB2BUtils.AdyenCustomException('Unhandled payment method of type: ' + clientDetails.paymentMethodType);
        }
    }

    private static PaymentsRequest buildCardPaymentRequest(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        PaymentsRequest paymentRequest = buildCommonPaymentsRequest(clientDetails, cart, adyenAdapter);
        paymentRequest.authenticationData = new AuthenticationData();
        paymentRequest.authenticationData.threeDSRequestData = new ThreeDSRequestData();
        paymentRequest.authenticationData.threeDSRequestData.nativeThreeDS = 'preferred';
        CardDetails cardPaymentMethod = (CardDetails)clientDetails.getPaymentMethodDetails();
        Boolean isFromSavedCard = cardPaymentMethod.storedPaymentMethodId != null;
        if (clientDetails.storePaymentMethod || isFromSavedCard) {
            paymentRequest.recurringProcessingModel = PaymentsRequest.RecurringProcessingModelEnum.CardOnFile;
            paymentRequest.shopperInteraction = isFromSavedCard
                ? PaymentsRequest.ShopperInteractionEnum.ContAuth
                : paymentRequest.shopperInteraction;
        }
        return paymentRequest;
    }

    private static PaymentsRequest buildCommonPaymentsRequest(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        Amount requestAmount = new Amount();
        requestAmount.value = (cart.GrandTotalAmount * AdyenB2BUtils.getAmountMultiplier(cart.CurrencyIsoCode)).round(System.RoundingMode.HALF_UP);
        requestAmount.currency_x = cart.CurrencyIsoCode;

        PaymentsRequest paymentRequest = new PaymentsRequest();
        paymentRequest.paymentMethod = clientDetails.getPaymentMethodDetails();
        paymentRequest.storePaymentMethod = clientDetails.storePaymentMethod;
        paymentRequest.merchantAccount = adyenAdapter.Merchant_Account__c;
        paymentRequest.amount = requestAmount;
        paymentRequest.reference = cart.Id;
        paymentRequest.shopperReference = cart.OwnerId;
        paymentRequest.shopperEmail = UserInfo.getUserEmail();
        paymentRequest.returnUrl = AdyenB2BUtils.getSiteUrl() + '/payment-processing';
        paymentRequest.billingAddress = clientDetails.getCompatibleBillingAddress();
        paymentRequest.browserInfo = clientDetails.getBrowserInfo();
        paymentRequest.applicationInfo = AdyenB2BUtils.getApplicationInfo(adyenAdapter.System_Integrator_Name__c);
        paymentRequest.channel = 'Web';
        paymentRequest.shopperInteraction = PaymentsRequest.ShopperInteractionEnum.Ecommerce;
        paymentRequest.origin = AdyenB2BUtils.getSiteUrl();

        return paymentRequest;
    }
}