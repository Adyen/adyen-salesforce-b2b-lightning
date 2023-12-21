@IsTest
private class AdyenDropInControllerTest {
    @IsTest
    private static void fetchPaymentMethodsSuccessTest() {
        // given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentMethodsSuccessMock());
        // when
        Test.startTest();
        AdyenDropInController.PaymentMethodsAndClientKey paymentMethodsAndClientKey = AdyenDropInController.fetchPaymentMethods(AdyenConstants.DEFAULT_ADAPTER_NAME);
        Test.stopTest();
        // then
        Assert.isNotNull(paymentMethodsAndClientKey);
        Assert.isNotNull(paymentMethodsAndClientKey.clientKey);
        Assert.isNotNull(paymentMethodsAndClientKey.paymentMethodsResponse);
        PaymentMethodsResponse paymentMethodsResponse = (PaymentMethodsResponse)JSON.deserialize(paymentMethodsAndClientKey.paymentMethodsResponse, PaymentMethodsResponse.class);
        Assert.isNotNull(paymentMethodsResponse.paymentMethods);
        Assert.isTrue(paymentMethodsResponse.paymentMethods.size() > 0);
    }

    @IsTest
    private static void fetchPaymentMethodsErrorTest() {
        // given - null adapter name
        try { // when
            AdyenDropInController.fetchPaymentMethods(null);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }

        // given - blank adapter name
        try { // when
            AdyenDropInController.fetchPaymentMethods('');
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }

        // given - 400 response
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.GenericErrorMock());
        try { // when
            AdyenDropInController.fetchPaymentMethods(AdyenConstants.DEFAULT_ADAPTER_NAME);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }
    }


    @IsTest(SeeAllData=true)
    private static void makePaymentTest() {
        //given
        Decimal unitPrice = 10.99;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        Decimal quantity = 2.0;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        String paymentMethodType = AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE;
        String paymentMethodBody = TestDataFactory.getPaymentMethodBody(paymentMethodType, 'Tester');
        String adyenAdapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        String endDigits = '1234';
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentsSuccessMock());
        // when
        Boolean makePaymentResult;
        System.runAs(buyerUser) {
            WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
            webCart.Status = 'Checkout';
            update webCart;
            Test.startTest();
            makePaymentResult = AdyenDropInController.makePayment(paymentMethodType, paymentMethodBody, adyenAdapterName, endDigits);
            Test.stopTest();
        }
        // then
        Assert.isTrue(makePaymentResult);
    }

    @IsTest(SeeAllData=true)
    private static void makePaymentErrorTest() {
        //given
        Decimal unitPrice = 10.99;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        Decimal quantity = 2.0;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        String paymentMethodType = AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE;
        String paymentMethodBody = TestDataFactory.getPaymentMethodBody(paymentMethodType, 'Tester');
        String adyenAdapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        String endDigits = '1234';
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.GenericErrorMock());
        // when
        Boolean makePaymentResult;
        System.runAs(buyerUser) {
            WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
            webCart.Status = 'Checkout';
            update webCart;
            try {
                Test.startTest();
                makePaymentResult = AdyenDropInController.makePayment(paymentMethodType, paymentMethodBody, adyenAdapterName, endDigits);
                Test.stopTest();
                Assert.fail();
            } catch (Exception ex) { // then
                Assert.isInstanceOfType(ex, AuraHandledException.class);
            }
        }
    }

    @IsTest
    private static void deserializePaymentMethodTest() {
        // given - scheme type
        String paymentMethodType = AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE;
        String paymentMethodBody = TestDataFactory.getPaymentMethodBody(paymentMethodType, 'Tester');
        // when
        PaymentMethodDetails paymentMethodDetails = AdyenDropInController.deserializePaymentMethod(paymentMethodType, paymentMethodBody);
        // then
        Assert.isInstanceOfType(paymentMethodDetails, CardDetails.class);
        CardDetails cardDetails = (CardDetails)paymentMethodDetails;
        Assert.areEqual('Tester', cardDetails.holderName);

        // given - unsupported payment method
        paymentMethodType = 'boleto';
        paymentMethodBody = TestDataFactory.getPaymentMethodBody(paymentMethodType, 'Tester');
        try { // when
            paymentMethodDetails = AdyenDropInController.deserializePaymentMethod(paymentMethodType, paymentMethodBody);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }

        // given - weird body
        paymentMethodType = AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE;
        paymentMethodBody = 'Attribute: "value"';
        try { // when
            paymentMethodDetails = AdyenDropInController.deserializePaymentMethod(paymentMethodType, paymentMethodBody);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }
    }

    @IsTest(SeeAllData=true)
    private static void buildPaymentsRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        PaymentMethodDetails paymentMethodDetails = null; // tested on deserializePaymentMethodTest
        Decimal unitPrice = 10.99;
        Decimal quantity = 1;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
        // when
        Test.startTest();
        PaymentsRequest paymentsRequest = AdyenDropInController.buildPaymentsRequest(paymentMethodDetails, webCart, adyenAdapter);
        Test.stopTest();
        // then
        Assert.areEqual(adyenAdapter.Merchant_Account__c, paymentsRequest.merchantAccount);
        Assert.areEqual(webCart.Id, paymentsRequest.reference);
        Assert.areEqual(webCart.OwnerId, paymentsRequest.shopperReference);
        Assert.areEqual(webCart.CurrencyIsoCode, paymentsRequest.amount.currency_x);
        Long expectedValue = (webCart.GrandTotalAmount * AdyenPaymentUtility.getAmountMultiplier(webCart.CurrencyIsoCode)).longValue();
        Assert.areEqual(expectedValue, paymentsRequest.amount.value);
    }
}