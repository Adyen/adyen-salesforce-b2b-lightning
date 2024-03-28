@IsTest
private class ClientDetailsTest {
    @IsTest
    private static void getPaymentMethodDetailsTest() {
        //given - scheme type
        ClientDetails clientDetails = new ClientDetails();
        clientDetails.paymentMethodType = AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE;
        clientDetails.paymentMethod = TestDataFactory.getPaymentMethodBody(clientDetails.paymentMethodType, 'Tester');
        // when
        PaymentMethodDetails paymentMethodDetails = clientDetails.getPaymentMethodDetails();
        // then
        Assert.isInstanceOfType(paymentMethodDetails, CardDetails.class);
        CardDetails cardDetails = (CardDetails)paymentMethodDetails;
        Assert.areEqual('Tester', cardDetails.holderName);

        // given - unsupported payment method
        clientDetails.paymentMethodType = 'unsupported type';
        clientDetails.paymentMethod = TestDataFactory.getPaymentMethodBody(clientDetails.paymentMethodType, 'Tester');
        try { // when
            paymentMethodDetails = clientDetails.getPaymentMethodDetails();
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }

        // given - weird body
        clientDetails.paymentMethodType = AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE;
        clientDetails.paymentMethod = 'Attribute: "value"';
        try { // when
            paymentMethodDetails = clientDetails.getPaymentMethodDetails();
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }
    }

    @IsTest
    private static void getCompatibleBillingAddressTest() {
        // given
        ClientDetails clientDetails = new ClientDetails();
        clientDetails.billingAddress = TestDataFactory.getBillingAddress();
        // when
        Address address = clientDetails.getCompatibleBillingAddress();
        // then
        Assert.isNotNull(address);
        Assert.areEqual('NL', address.country);
        Assert.areEqual('Rotterdam', address.city);
        Assert.areEqual('3012 AH', address.postalCode);
    }

    @IsTest
    private static void getBrowserInfoTest() {
        // given
        ClientDetails clientDetails = new ClientDetails();
        clientDetails.browserInfo = TestDataFactory.getBrowserInfo();
        // when
        BrowserInfo browserInfo = clientDetails.getBrowserInfo();
        // then
        Assert.areEqual('en-US', browserInfo.language);
        Assert.areEqual('*/*', browserInfo.acceptHeader);
        Assert.isFalse(browserInfo.javaEnabled);
        Assert.areEqual(180, browserInfo.timeZoneOffset);
    }

    @IsTest
    private static void fakeFullCardNumberTest() {
        // given
        ClientDetails.CardData cardData = new ClientDetails.CardData();
        cardData.brand = 'amex';
        cardData.holderName = 'Danilo Cardoso';
        cardData.bin = '123456';
        cardData.lastFourDigits = '4321';
        // when
        String fakeCardNumber = cardData.fakeFullCardNumber();
        // then
        Assert.isTrue(fakeCardNumber.length() > 14);

        // given: no bin
        cardData.bin = null;
        // when
        fakeCardNumber = cardData.fakeFullCardNumber();
        // then
        Assert.isTrue(fakeCardNumber.length() > 14);
    }

    @IsTest
    private static void getBrandSFCompatibleTest() {
        // given
        ClientDetails.CardData cardData = new ClientDetails.CardData();
        cardData.brand = 'amex';
        // when
        String sfPaymentMethodType = cardData.getBrandSFCompatible();
        // then
        Assert.areEqual(AdyenB2BConstants.ADYEN_PAYMENT_TYPE_TO_SF_TYPE.get(cardData.brand), sfPaymentMethodType);

        // given - a type not in the constants
        cardData.brand = 'unknown';
        // when
        sfPaymentMethodType = cardData.getBrandSFCompatible();
        // then
        Assert.areEqual(cardData.brand, sfPaymentMethodType);
    }
}