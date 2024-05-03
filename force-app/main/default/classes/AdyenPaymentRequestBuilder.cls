public with sharing class AdyenPaymentRequestBuilder {
    public static PaymentsRequest create(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        if (clientDetails.getPaymentMethodDetails() instanceof CardDetails) {
            return buildCardPaymentRequest(clientDetails, cart, adyenAdapter);
        } else if (clientDetails.getPaymentMethodDetails() instanceof SepaDirectDebitDetails) {
            return buildSepaPaymentRequest(clientDetails, cart, adyenAdapter);
        } else {
            throw new AdyenB2BUtils.AdyenCustomException('Unhandled payment method of type: ' + clientDetails.paymentMethodType);
        }
    }

    private static PaymentsRequest buildCardPaymentRequest(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        PaymentsRequest paymentsRequest = buildCommonPaymentsRequest(clientDetails, cart, adyenAdapter);
        paymentsRequest.authenticationData = new AuthenticationData();
        paymentsRequest.authenticationData.threeDSRequestData = new ThreeDSRequestData();
        paymentsRequest.authenticationData.threeDSRequestData.nativeThreeDS = 'preferred';
        return paymentsRequest;
    }

    private static PaymentsRequest buildSepaPaymentRequest(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
        return buildCommonPaymentsRequest(clientDetails, cart, adyenAdapter);
    }

    private static PaymentsRequest buildCommonPaymentsRequest(ClientDetails clientDetails, WebCart cart, Adyen_Adapter__mdt adyenAdapter) {
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

        return paymentsRequest;
    }
}