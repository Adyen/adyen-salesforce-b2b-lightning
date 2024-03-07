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
        // given
        ClientDetails clientDetails = TestDataFactory.createClientDetails();
        Decimal unitPrice = 10.99;
        Decimal quantity = 1;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentsSuccessMock());
        // when
        String makePaymentResult;
        System.runAs(buyerUser) {
            WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
            webCart.Status = 'Checkout';
            update webCart;
            Test.startTest();
            makePaymentResult = AdyenDropInController.makePayment(clientDetails);
            Test.stopTest();
        }
        // then
        Assert.isNotNull(makePaymentResult);
        PaymentsResponse paymentsResp = (PaymentsResponse)JSON.deserialize(makePaymentResult, PaymentsResponse.class);
        Assert.isNotNull(paymentsResp.pspReference);
        Assert.isNull(paymentsResp.refusalReason);
        Assert.areEqual(PaymentsResponse.ResultCodeEnum.AUTHORISED, paymentsResp.resultCode);
    }

    @IsTest(SeeAllData=true)
    private static void makePaymentErrorTest() {
        // given
        ClientDetails clientDetails = TestDataFactory.createClientDetails();
        Decimal unitPrice = 10.99;
        Decimal quantity = 1;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);

        Test.setMock(HttpCalloutMock.class, new TestDataFactory.GenericErrorMock());
        // when
        String makePaymentResult;
        System.runAs(buyerUser) {
            WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
            webCart.Status = 'Checkout';
            update webCart;
            try {
                Test.startTest();
                makePaymentResult = AdyenDropInController.makePayment(clientDetails);
                Test.stopTest();
                Assert.fail();
            } catch (Exception ex) {
                Assert.isInstanceOfType(ex, AuraHandledException.class);
            }
        }
    }

    @IsTest(SeeAllData=true)
    private static void buildPaymentsRequestTest() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails();
        Decimal unitPrice = 10.99;
        Decimal quantity = 1;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
        // when
        Test.startTest();
        PaymentsRequest paymentsRequest = AdyenDropInController.buildPaymentsRequest(clientDetails, webCart, adyenAdapter);
        Test.stopTest();
        // then
        Assert.areEqual(adyenAdapter.Merchant_Account__c, paymentsRequest.merchantAccount);
        Assert.areEqual(webCart.Id, paymentsRequest.reference);
        Assert.areEqual(webCart.OwnerId, paymentsRequest.shopperReference);
        Assert.areEqual(webCart.CurrencyIsoCode, paymentsRequest.amount.currency_x);
        Long expectedValue = (webCart.GrandTotalAmount * AdyenPaymentUtility.getAmountMultiplier(webCart.CurrencyIsoCode)).longValue();
        Assert.isTrue(paymentsRequest.returnUrl.contains('/checkout'));
        Assert.areEqual(expectedValue, paymentsRequest.amount.value);
        Assert.areEqual('NL', paymentsRequest.billingAddress.country);
        Assert.areEqual('Rotterdam', paymentsRequest.billingAddress.city);
        Assert.areEqual('3012 AH', paymentsRequest.billingAddress.postalCode);
        Assert.areEqual('en-US', paymentsRequest.browserInfo.language);
        Assert.areEqual('*/*', paymentsRequest.browserInfo.acceptHeader);
        Assert.areEqual('Web', paymentsRequest.channel);
        Assert.areEqual(Url.getOrgDomainUrl().toExternalForm(), paymentsRequest.origin);
    }

    @IsTest(SeeAllData=true)
    private static void makeDetailsCallTest() {
        // given
        Object stateData = TestDataFactory.getStateData();
        String adyenAdapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        TestDataFactory.PaymentsSuccessMock paymentsSuccessMock = new TestDataFactory.PaymentsSuccessMock();
        Decimal unitPrice = 10.99;
        Decimal quantity = 1;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        String makeDetailsCallResult;
        PaymentAuthorization paymentAuthorization;
        System.runAs(buyerUser) {
            WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
            paymentsSuccessMock.cartId = webCart.Id;
            Test.setMock(HttpCalloutMock.class, paymentsSuccessMock);
            webCart.Status = 'Checkout';
            CardPaymentMethod cardPaymentMethod = new CardPaymentMethod(Status = 'Active', ProcessingMode = 'External');
            insert cardPaymentMethod;
            webCart.PaymentMethodId = cardPaymentMethod.Id;
            update webCart;
            paymentAuthorization = new PaymentAuthorization(Amount = unitPrice, ProcessingMode = 'External', Status = 'Pending', PaymentMethodId = cardPaymentMethod.Id);
            insert paymentAuthorization;
            // when
            Test.startTest();
            makeDetailsCallResult = AdyenDropInController.makeDetailsCall(stateData, adyenAdapterName);
            Test.stopTest();
        }
        // then
        Assert.isNotNull(makeDetailsCallResult);
        PaymentsResponse paymentsResp = (PaymentsResponse)JSON.deserialize(makeDetailsCallResult, PaymentsResponse.class);
        String pspReference = [SELECT GatewayRefNumber FROM PaymentAuthorization WHERE Id = :paymentAuthorization.Id].GatewayRefNumber;
        Assert.areEqual(paymentsResp.pspReference, pspReference);
    }

    @IsTest
    private static void buildPaymentsRequestTestForThreeDecimalCurrency() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails();
        Decimal unitPrice = 5.5555; // Example unit price with three decimal places
        String currencyIsoCode = 'JOD'; // Example currency code with three decimal places
        WebCart webCart = new WebCart(CurrencyIsoCode = currencyIsoCode);

        String jsonString = JSON.serialize(webCart);
        Map<String,Object> dataMap = (Map<String,Object>)JSON.deserializeUntyped(jsonString);
        dataMap.put('GrandTotalAmount', unitPrice);
        jsonString = JSON.serialize(dataMap);
        webCart = (WebCart)JSON.deserialize(jsonString, WebCart.class);

        // when
        Test.startTest();
        PaymentsRequest paymentsRequest = AdyenDropInController.buildPaymentsRequest(clientDetails, webCart, adyenAdapter);
        Test.stopTest();

        // then
        Assert.areEqual(adyenAdapter.Merchant_Account__c, paymentsRequest.merchantAccount);
        Assert.areEqual(webCart.Id, paymentsRequest.reference);
        Assert.areEqual(webCart.OwnerId, paymentsRequest.shopperReference);
        Assert.areEqual(webCart.CurrencyIsoCode, paymentsRequest.amount.currency_x);

        // Calculate expected value with three decimal places
        Long expectedValue = (webCart.GrandTotalAmount * AdyenPaymentUtility.getAmountMultiplier(webCart.CurrencyIsoCode)).round(RoundingMode.HALF_UP);
        Assert.isTrue(paymentsRequest.returnUrl.contains('/checkout'));
        Assert.areEqual(expectedValue, paymentsRequest.amount.value);
        Assert.areEqual('NL', paymentsRequest.billingAddress.country);
        Assert.areEqual('Rotterdam', paymentsRequest.billingAddress.city);
        Assert.areEqual('3012 AH', paymentsRequest.billingAddress.postalCode);
        Assert.areEqual('en-US', paymentsRequest.browserInfo.language);
        Assert.areEqual('*/*', paymentsRequest.browserInfo.acceptHeader);
        Assert.areEqual('web', paymentsRequest.channel);
        Assert.areEqual(Url.getOrgDomainUrl().toExternalForm(), paymentsRequest.origin);
    }
}