@IsTest
private class AdyenDropInControllerTest {
    @IsTest(SeeAllData=true)
    static void fetchPaymentMethodsSuccessTest() {
        // given
        Decimal unitPrice = 10.99;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentMethodsSuccessMock());
        // when
        AdyenDropInController.PaymentMethodsAndClientKey paymentMethodsAndClientKey;
        System.runAs(buyerUser) {
            paymentMethodsAndClientKey = createCartAndFetchPaymentMethods(webStore.Id);
        }
        // then
        Assert.isNotNull(paymentMethodsAndClientKey);
        Assert.isNotNull(paymentMethodsAndClientKey.paymentMethodsResponse);
        PaymentMethodsResponse paymentMethodsResponse = (PaymentMethodsResponse)JSON.deserialize(paymentMethodsAndClientKey.paymentMethodsResponse, PaymentMethodsResponse.class);
        Assert.isNotNull(paymentMethodsResponse.paymentMethods);
        Assert.isTrue(paymentMethodsResponse.paymentMethods.size() > 0);
    }

    @IsTest
    static void fetchPaymentMethodsErrorTest() {
        // given - null adapter name
        // when
        AdyenDropInController.PaymentMethodsAndClientKey fetchPaymentResult = AdyenDropInController.fetchPaymentMethods(null, false);
        // then
        Assert.isNull(fetchPaymentResult);
        Assert.areEqual(1, [SELECT COUNT() FROM LogEntry__c WHERE Severity__c LIKE :LogEntry.SeverityLevel.ERROR.name()]);

        // given - blank adapter name
        // when
        fetchPaymentResult = AdyenDropInController.fetchPaymentMethods(null, false);
        // then
        Assert.isNull(fetchPaymentResult);
        Assert.areEqual(2, [SELECT COUNT() FROM LogEntry__c WHERE Severity__c LIKE :LogEntry.SeverityLevel.ERROR.name()]);

        // given - 400 response
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.GenericErrorMock());
        // when
        fetchPaymentResult = AdyenDropInController.fetchPaymentMethods(AdyenConstants.DEFAULT_ADAPTER_NAME, false);
        // then
        Assert.isNull(fetchPaymentResult);
        Assert.areEqual(3, [SELECT COUNT() FROM LogEntry__c WHERE Severity__c LIKE :LogEntry.SeverityLevel.ERROR.name()]);
    }

    @IsTest(SeeAllData=true)
    static void makePaymentTest() {
        // given
        Decimal unitPrice = 10.99;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentsSuccessMock());
        // when
        AdyenDropInController.MinimalPaymentResponse makePaymentResult;
        System.runAs(buyerUser) {
            makePaymentResult = createCartAndMakePayment(webStore.Id, AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE);
        }
        // then
        Assert.isNotNull(makePaymentResult);
        Assert.isNull(makePaymentResult.action);
        Assert.isTrue(makePaymentResult.paymentSuccessful);
    }
    
    @IsTest(SeeAllData=true) 
    static void makeSepaPaymentTest(){
        // given
        Decimal unitPrice = 10.99;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentsSuccessMock());
        // when
        AdyenDropInController.MinimalPaymentResponse makePaymentResult;
        System.runAs(buyerUser) {
            makePaymentResult = createCartAndMakePayment(webStore.Id, AdyenB2BConstants.SEPA_DIRECT_DEBIT);
        }
        // then
        Assert.isNotNull(makePaymentResult);
        Assert.isNull(makePaymentResult.action);
        Assert.isTrue(makePaymentResult.paymentSuccessful);
    }

    @IsTest(SeeAllData=true)
    static void makePaymentNotAuthorisedTest() {
        // given
        Decimal unitPrice = 10.99;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentsDeniedMock());
        // when
        AdyenDropInController.MinimalPaymentResponse makePaymentResult;
        System.runAs(buyerUser) {
            makePaymentResult = createCartAndMakePayment(webStore.Id, AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE);
        }
        // then
        Assert.isNotNull(makePaymentResult);
        Assert.isNull(makePaymentResult.action);
        Assert.isFalse(makePaymentResult.paymentSuccessful);
    }

    @IsTest(SeeAllData=true)
    static void makePaymentErrorTest() {
        // given
        Decimal unitPrice = 10.99;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.GenericErrorMock());
        // when
        AdyenDropInController.MinimalPaymentResponse makePaymentResult;
        System.runAs(buyerUser) {
            makePaymentResult = createCartAndMakePayment(webStore.Id, AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE);
        }
        // then
        Assert.isNull(makePaymentResult);
    }

    @IsTest(SeeAllData=true)
    static void makeDetailsCallTest() {
        // given
        Object stateData = TestDataFactory.getStateData();
        String adyenAdapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;
        TestDataFactory.PaymentsSuccessMock paymentsSuccessMock = new TestDataFactory.PaymentsSuccessMock();
        Decimal unitPrice = 10.99;
        Decimal quantity = 1;
        String currencyIsoCode = TestDataFactory.ACTIVE_CURRENCY;
        WebStore webStore = TestDataFactory.setUpWebStore(unitPrice, currencyIsoCode);
        User buyerUser = TestDataFactory.setUpBuyerUser(webStore.Id);
        AdyenDropInController.MinimalPaymentResponse makeDetailsCallResult;
        PaymentAuthorization paymentAuthorization;
        Test.setMock(HttpCalloutMock.class, paymentsSuccessMock);
        System.runAs(buyerUser) {
            WebCart webCart = TestDataFactory.createCartWithOneItem(webStore.Id, quantity);
            paymentsSuccessMock.cartId = webCart.Id;
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
        Assert.isNull(makeDetailsCallResult.action);
        Assert.isTrue(makeDetailsCallResult.paymentSuccessful);
    }

    @IsTest
    static void buildPaymentsRequestTestForThreeDecimalCurrency() {
        // given
        Adyen_Adapter__mdt adyenAdapter = AdyenB2BUtils.retrieveAdyenAdapter(AdyenConstants.DEFAULT_ADAPTER_NAME);
        ClientDetails clientDetails = TestDataFactory.createClientDetails(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE);
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
        PaymentsRequest paymentsRequest = AdyenPaymentRequestBuilder.create(clientDetails, webCart, adyenAdapter);
        Test.stopTest();

        // Calculate expected value with three decimal places
        Long expectedValue = (webCart.GrandTotalAmount * AdyenB2BUtils.getAmountMultiplier(webCart.CurrencyIsoCode)).round(RoundingMode.HALF_UP);
        Assert.areEqual(expectedValue, paymentsRequest.amount.value);
    }

    @IsTest
    static void handleFailedPaymentAttemptTest() {
        // given
        PaymentsResponse paymentsResp = (PaymentsResponse)JSON.deserialize(TestDataFactory.mockPaymentsNotAuthorizedResponse('0a61Q000000LNcFQAW'), PaymentsResponse.class);
        // when
        AdyenDropInController.handleFailedPaymentAttempt(paymentsResp, null);
        // then
        Assert.areEqual(1, [SELECT COUNT() FROM LogEntry__c WHERE Severity__c LIKE :LogEntry.SeverityLevel.INFO.name()]);
    }

    static AdyenDropInController.MinimalPaymentResponse createCartAndMakePayment(Id webStoreId, String paymentMethodType) {
        WebCart webCart = TestDataFactory.createCartWithOneItem(webStoreId, 1);
        webCart.Status = 'Checkout';
        update webCart;
        Test.startTest();
        AdyenDropInController.MinimalPaymentResponse response = AdyenDropInController.makePayment(TestDataFactory.createClientDetails(paymentMethodType));
        Test.stopTest();
        return response;
    }

    static AdyenDropInController.PaymentMethodsAndClientKey createCartAndFetchPaymentMethods(Id webStoreId) {
        WebCart webCart = TestDataFactory.createCartWithOneItem(webStoreId, 1);
        webCart.Status = 'Checkout';
        update webCart;
        Test.startTest();
        AdyenDropInController.PaymentMethodsAndClientKey response  = AdyenDropInController.fetchPaymentMethods(AdyenConstants.DEFAULT_ADAPTER_NAME, false);
        Test.stopTest();
        return response;
    }
}