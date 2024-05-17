public with sharing class ClientDetails {
    @AuraEnabled
    public String paymentMethodType { get; set; }
    @AuraEnabled
    public String paymentMethod { get; set; }
    @AuraEnabled
    public String adyenAdapterName { get; set; }
    @AuraEnabled
    public String browserInfo { get; set; }
    @AuraEnabled
    public String billingAddress { get; set; }
    @AuraEnabled
    public CardData cardData { get; set; }

    public Address getCompatibleBillingAddress() {
        Address addressForAdyen = (Address)JSON.deserialize(this.billingAddress, Address.class);
        Map<String,Object> addressUntypedMap = (Map<String,Object>)JSON.deserializeUntyped(this.billingAddress);
        addressForAdyen.stateOrProvince = (String)addressUntypedMap.get('region');
        return addressForAdyen;
    }

    public PaymentMethodDetails getPaymentMethodDetails() {
        if (paymentMethodType.equalsIgnoreCase(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE)) {
            return (CardDetails)JSON.deserialize(paymentMethod, CardDetails.class);
        } else if (paymentMethodType.equalsIgnoreCase(AdyenB2BConstants.SEPA_DIRECT_DEBIT)) {
            return (SepaDirectDebitDetails)JSON.deserialize(paymentMethod, SepaDirectDebitDetails.class);
        } else if (paymentMethodType.equalsIgnoreCase(AdyenB2BConstants.ACH_DIRECT_DEBIT)) {
            return (ACHDetails)JSON.deserialize(paymentMethod, ACHDetails.class);
        } else {
            throw new AdyenB2BUtils.AdyenCustomException('Unhandled payment method of type: ' + paymentMethodType);
        }
    }

    public BrowserInfo getBrowserInfo() {
        if (this.browserInfo == null) {
            return new BrowserInfo();
        } else {
            return (BrowserInfo) JSON.deserialize(this.browserInfo, BrowserInfo.class);
        }
    }
    

    public class CardData {
        @AuraEnabled
        public String bin { get; set; }
        @AuraEnabled
        public String lastFourDigits { get; set; }
        @AuraEnabled
        public String brand { get; set; }
        @AuraEnabled
        public String holderName { get; set; }

        public String fakeFullCardNumber() {
            if (String.isBlank(bin)) {
                return '000000000000' + lastFourDigits;
            } else {
                return bin + '000000' + lastFourDigits;
            }
        }

        public String getBrandSFCompatible() {
            String salesForcePayMethodType = AdyenB2BConstants.ADYEN_PAYMENT_TYPE_TO_SF_TYPE.get(brand);
            return String.isNotBlank(salesForcePayMethodType) ? salesForcePayMethodType : brand;
        }
    }
}