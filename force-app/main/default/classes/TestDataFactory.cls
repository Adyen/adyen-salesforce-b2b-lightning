@IsTest
public without sharing class TestDataFactory {
    public static final String ACTIVE_CURRENCY = [SELECT IsoCode FROM CurrencyType WHERE IsActive = TRUE LIMIT 1].IsoCode;

    public static ClientDetails createClientDetails(String paymentType) {
        ClientDetails clientDetails = new ClientDetails();
        clientDetails.paymentMethodType = paymentType;
        clientDetails.paymentMethod = TestDataFactory.getPaymentMethodBody(paymentType, 'Tester');
        clientDetails.billingAddress = TestDataFactory.getBillingAddress();
        clientDetails.browserInfo = TestDataFactory.getBrowserInfo();
        clientDetails.adyenAdapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;

        if (paymentType.equalsIgnoreCase(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE)) {
            ClientDetails.CardData cardData = new ClientDetails.CardData();
            cardData.brand = 'amex';
            cardData.holderName = 'Danilo Cardoso';
            cardData.bin = '123456';
            cardData.lastFourDigits = '4321';
            clientDetails.cardData = cardData;
        }

        return clientDetails;
    }

    public static WebStore setUpWebStore(Decimal unitPrice, String currencyIsoCode) {
        WebStore testWebStore = new WebStore(Name = 'TestWebStore');
        insert testWebStore;

        Product2 product = createProductInStore(unitPrice, currencyIsoCode, testWebStore.Id);
        Account buyerAccount = createBuyerAccount(currencyIsoCode, testWebStore.Id);
        createEntitlementPolicy(buyerAccount.Id, product.Id, testWebStore.Id);

        return testWebStore;
    }

    public static WebCart createCartWithOneItem(Id webStoreId, Decimal quantity) {
        Id buyerGroupId = [SELECT BuyerGroupId FROM WebStoreBuyerGroup WHERE WebStoreId = :webStoreId].BuyerGroupId;
        Id buyerAccountId = [SELECT BuyerId FROM BuyerGroupMember WHERE BuyerGroupId = :buyerGroupId].BuyerId;
        Id catalogId = [SELECT ProductCatalogId FROM WebStoreCatalog WHERE SalesStoreId = :webStoreId].ProductCatalogId;
        Product2 product = [SELECT ProductId, Product.CurrencyIsoCode FROM ProductCategoryProduct WHERE ProductCategory.CatalogId = :catalogId].Product;

        ConnectApi.CartSummary cartSummary;
        ConnectApi.CartInput cartInput = new ConnectApi.CartInput();
        cartInput.currencyIsoCode = product.CurrencyIsoCode;
        cartInput.effectiveAccountId = buyerAccountId;
        cartSummary = ConnectApi.CommerceCart.createCart(webStoreId, cartInput);

        ConnectApi.CartItemInput cartItemInput = new ConnectApi.CartItemInput();
        cartItemInput.productId = product.Id;
        cartItemInput.quantity = String.valueOf(quantity);
        cartItemInput.type = ConnectApi.CartItemType.Product;
        ConnectApi.CommerceCart.addItemToCart(webStoreId, buyerAccountId, cartSummary.cartId, cartItemInput);

        return [SELECT GrandTotalAmount, CurrencyIsoCode, OwnerId FROM WebCart WHERE Id = :cartSummary.cartId];
    }

    public static WebCart mockCartRecord(Id cartId, Id ownerId, Decimal totalValue) {
        String mockedCart = '{"attributes":{"type":"WebCart"},"Id":"' + cartId + '","OwnerId":"' + ownerId + '","CurrencyIsoCode":"' + ACTIVE_CURRENCY + '","GrandTotalAmount":' + totalValue + '}';
        return (WebCart)JSON.deserialize(mockedCart, WebCart.class);
    }

    public static Product2 createProductInStore(Decimal value, String currencyIsoCode, Id webStoreId) {
        Product2 product = new Product2(
            Name = 'Test Product',
            Description = 'Test Description',
            ProductCode = 'TestCode',
            StockKeepingUnit = 'M2I',
            IsActive = true,
            CurrencyIsoCode = currencyIsoCode
        );
        insert product;

        Pricebook2 customPriceBook = new Pricebook2();
        customPriceBook.Name = 'Test price book';
        customPriceBook.IsActive = true;
        customPriceBook.CurrencyIsoCode = currencyIsoCode;
        insert customPriceBook;

        PricebookEntry standardPricebookEntry = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = product.Id,
            UnitPrice = value,
            IsActive = true,
            UseStandardPrice = false
        );
        insert standardPricebookEntry;

        PricebookEntry pricebookEntry = new PricebookEntry(
            Pricebook2Id = customPriceBook.Id,
            Product2Id = product.Id,
            UnitPrice = value,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pricebookEntry;

        WebStorePricebook webStorePricebook = new WebStorePricebook();
        webStorePricebook.Pricebook2Id = customPriceBook.Id;
        webStorePricebook.WebStoreId = webStoreId;
        webStorePricebook.IsActive = true;
        insert webStorePricebook;

        ProductCatalog productCatalog = new ProductCatalog();
        productCatalog.Name = 'Catalog Test';
        insert productCatalog;

        WebStoreCatalog webStoreCatalog = new WebStoreCatalog();
        webStoreCatalog.ProductCatalogId = productCatalog.Id;
        webStoreCatalog.SalesStoreId = webStoreId;
        insert webStoreCatalog;

        ProductCategory productCategory = new ProductCategory();
        productCategory.Name = 'Category Test';
        productCategory.CatalogId = productCatalog.Id;
        insert productCategory;

        ProductCategoryProduct productCategoryProduct = new ProductCategoryProduct();
        productCategoryProduct.ProductId = product.Id;
        productCategoryProduct.ProductCategoryId = productCategory.Id;
        insert productCategoryProduct;

        return product;
    }

    public static Account createBuyerAccount(String currencyIsoCode, Id webStoreId) {
        Account testAccount = new Account(Name = 'TestAccount');
        insert testAccount;

        BuyerAccount buyerAccount = new BuyerAccount();
        buyerAccount.BuyerId = testAccount.Id;
        buyerAccount.Name = 'Test Buyer Account (BA)';
        buyerAccount.IsActive = true;
        buyerAccount.CurrencyIsoCode = currencyIsoCode;
        buyerAccount.CreditStatus = 'Good Credit';
        insert buyerAccount;

        BuyerGroup buyerGroup = new BuyerGroup();
        buyerGroup.Name = 'Buyer Group Test';
        insert buyerGroup;

        WebStoreBuyerGroup webStoreBuyerGroup = new WebStoreBuyerGroup();
        webStoreBuyerGroup.BuyerGroupId = buyerGroup.Id;
        webStoreBuyerGroup.WebStoreId = webStoreId;
        insert webStoreBuyerGroup;

        BuyerGroupMember buyerGroupMember = new BuyerGroupMember();
        buyerGroupMember.BuyerGroupId = buyerGroup.Id;
        buyerGroupMember.BuyerId = testAccount.Id;
        insert buyerGroupMember;

        return testAccount;
    }

    public static CommerceEntitlementPolicy createEntitlementPolicy(Id buyerAccountId, Id productId, Id webStoreId) {
        Id buyerGroupId = [SELECT BuyerGroupId FROM BuyerGroupMember WHERE BuyerId = :buyerAccountId].BuyerGroupId;
        Id customPriceBookId = [SELECT Pricebook2Id FROM WebStorePricebook WHERE WebStoreId = :webStoreId].Pricebook2Id;
        CommerceEntitlementPolicy commerceEntitlementPolicy = new CommerceEntitlementPolicy();
        commerceEntitlementPolicy.Name = 'Test Entitlement Policy';
        commerceEntitlementPolicy.CanViewPrice = true;
        commerceEntitlementPolicy.CanViewProduct = true;
        commerceEntitlementPolicy.IsActive = true;
        insert commerceEntitlementPolicy;

        CommerceEntitlementBuyerGroup commerceEntitlementBuyerGroup = new CommerceEntitlementBuyerGroup();
        commerceEntitlementBuyerGroup.BuyerGroupId = buyerGroupId;
        commerceEntitlementBuyerGroup.PolicyId = commerceEntitlementPolicy.Id;
        insert commerceEntitlementBuyerGroup;

        CommerceEntitlementProduct commerceEntitlementProduct = new CommerceEntitlementProduct();
        commerceEntitlementProduct.PolicyId = commerceEntitlementPolicy.Id;
        commerceEntitlementProduct.ProductId = productId;
        insert commerceEntitlementProduct;

        BuyerGroupPricebook buyerGroupPricebook = new BuyerGroupPricebook();
        buyerGroupPricebook.Pricebook2Id = customPriceBookId;
        buyerGroupPricebook.BuyerGroupId = buyerGroupId;
        insert buyerGroupPricebook;

        return commerceEntitlementPolicy;
    }

    public static User setUpBuyerUser(Id webStoreId) {
        Id buyerGroupId = [SELECT BuyerGroupId FROM WebStoreBuyerGroup WHERE WebStoreId = :webStoreId].BuyerGroupId;
        Id buyerAccountId = [SELECT BuyerId FROM BuyerGroupMember WHERE BuyerGroupId = :buyerGroupId].BuyerId;
        Contact buyerContact = new Contact(LastName = 'Test', AccountId = buyerAccountId);
        insert buyerContact;

        User adminUser = [SELECT Id FROM User WHERE Profile.Name = 'System Administrator' LIMIT 1];
        System.runAs (adminUser) {
            UserRole role = new UserRole(DeveloperName = 'MyCustomRole', Name = 'My Role');
            insert role;
            adminUser.UserRoleId = role.Id;
            update adminUser;
            makeBuyerUser(buyerContact.Id, buyerAccountId);
        }

        return [SELECT Id FROM User WHERE ContactId = :buyerContact.Id];
    }

    public static void makeBuyerUser(Id buyerContactId, Id buyerAccountId) {
        Id communityProfileId = [SELECT Id FROM Profile WHERE Name = 'Customer Community Plus User' LIMIT 1].Id;

        User buyerUser = createUser(communityProfileId, buyerContactId);
        insert buyerUser;

        UserRole userRole = new UserRole();
        userRole.PortalAccountId = buyerAccountId;
        userRole.PortalType = 'CustomerPortal';
        insert userRole;

        buyerUser.UserRoleId = userRole.Id;
        update buyerUser;

        List<PermissionSetAssignment> permissionSetAssignments = new List<PermissionSetAssignment>();
        for (PermissionSet permissionSet : [SELECT Id FROM PermissionSet WHERE Name IN ('B2BBuyer', 'Adyen_Checkout_Access')]) {
            PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment();
            permissionSetAssignment.AssigneeId = buyerUser.Id;
            permissionSetAssignment.PermissionSetId = permissionSet.Id;
            permissionSetAssignments.add(permissionSetAssignment);
        }
        insert permissionSetAssignments;
    }

    public static User createUser(Id profileId, Id contactId) {
        return new User(
                Username = 'test_' + Math.random() + '@adyen.com.w24.b2b',
                FirstName = 'Test-First',
                LastName = 'Test-Last',
                Alias = 'test',
                Email = 'test' + Math.random() + '@adyen.test.com',
                CommunityNickname = String.valueOf(Math.random()).substring(0,6),
                ProfileId = profileId,
                TimeZoneSidKey = 'Europe/Amsterdam',
                LocaleSidKey = 'nl_NL',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ContactId = contactId
        );
    }

    public static PaymentAuthorization createPaymentAuthorization(String status) {
        PaymentAuthorization paymentAuthorization = new PaymentAuthorization();
        paymentAuthorization.GatewayRefNumber = 'QFQTPCQ8HXSKGK82';
        paymentAuthorization.Amount = 10.93;
        paymentAuthorization.ProcessingMode = 'External';
        paymentAuthorization.Status = status;
        return paymentAuthorization;
    }

    public static Order insertOrderAndRelatedRecords(Id acctId, Decimal productUnitPrice, Decimal prodTaxAmount) {
        Product2 product = new Product2(
                Name = 'Test Product',
                Description = 'Test Description'
        );
        insert(product);

        PricebookEntry pricebookEntry = new PricebookEntry(
                Pricebook2Id = Test.getStandardPricebookId(),
                Product2Id = product.Id,
                UnitPrice = productUnitPrice,
                IsActive = true,
                UseStandardPrice = false
        );
        insert pricebookEntry;

        Order order = new Order(
                AccountId = acctId,
                EffectiveDate = Date.newInstance(2023, 1, 1),
                OrderedDate = Date.newInstance(2023, 1, 1),
                Status = 'Draft',
                Pricebook2Id = pricebookEntry.Pricebook2Id
        );
        insert(order);

        OrderDeliveryMethod orderDeliveryMethod = new OrderDeliveryMethod(
                Name = 'Order Delivery Method',
                ProductId = product.Id
        );
        insert orderDeliveryMethod;

        OrderDeliveryGroup orderDeliveryGroup = new OrderDeliveryGroup(
                DeliverToName = 'Buyer User',
                DeliverToStreet = 'test Street',
                DeliverToCity = 'Minneapolis',
                DeliverToState = 'MN',
                DeliverToPostalCode = '55402',
                DeliverToCountry = 'US',
                OrderDeliveryMethodId = orderDeliveryMethod.Id,
                OrderId = order.Id
        );
        insert orderDeliveryGroup;

        OrderItem orderItem = new OrderItem(
                Description = 'Test Product',
                OrderId = order.Id,
                Product2Id = product.Id,
                PricebookEntryId = pricebookEntry.Id,
                UnitPrice = productUnitPrice,
                Quantity = 1,
                TotalLineAmount = productUnitPrice,
                Type = 'Order Product',
                OrderDeliveryGroupId = orderDeliveryGroup.Id
        );
        insert orderItem;

        OrderItemTaxLineItem tax = new OrderItemTaxLineItem(
                OrderItemId = orderItem.Id,
                Amount = prodTaxAmount,
                Name = 'Tax for product',
                Type = 'Estimated',
                TaxEffectiveDate = System.today()
        );
        insert tax;

        order.Status = 'Activated';
        update order;

        return order;
    }

    public static OrderPaymentSummary createOrderSummaryRecords(Id orderId) {
        ConnectApi.OrderSummaryInputRepresentation osir = new ConnectApi.OrderSummaryInputRepresentation();
        osir.orderId = orderId;
        osir.orderLifeCycleType = 'MANAGED';
        ConnectApi.OrderSummaryOutputRepresentation osor = ConnectApi.OrderSummaryCreation.createOrderSummary(osir);

        OrderPaymentSummary orderPaymentSummary = new OrderPaymentSummary(
                OrderSummaryId = osor.orderSummaryId,
                Method = 'Visa',
                Type = 'Unknown'
        );
        insert orderPaymentSummary;

        return orderPaymentSummary;
    }

    // HTTP Mocks
    public class PaymentMethodsSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(mockPaymentMethodsSuccessfulResponse(), 200);
        }
    }

    public class GenericErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(genericErrorResponse(), 400);
        }
    }

    public class PaymentsSuccessMock implements HttpCalloutMock {
        public Id cartId = '0a61Q000000LFiYQAW';
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(mockPaymentsSuccessfulResponse(cartId), 200);
        }
    }

    public class PaymentsDeniedMock implements HttpCalloutMock {
        public Id cartId = '0a61Q000000LFiYQAW';
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(mockPaymentsNotAuthorizedResponse(cartId), 200);
        }
    }

    public static String getPaymentMethodBody(String type, String shopperName) {
        if (type.equalsIgnoreCase(AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE)) {
            return '{"type":"' + type + '","holderName":"' + shopperName + '","brand":"visa"}';
        } else if (type.equalsIgnoreCase(AdyenB2BConstants.SEPA_DIRECT_DEBIT)) {
            return '{"type" : "' + type + '", "ownerName" : "' + shopperName + '", "iban" : "NL13 TEST 0123 4567 89"}';
        } else if (type.equalsIgnoreCase(AdyenB2BConstants.ACH_DIRECT_DEBIT)) {
            return '{"type":"'+ type +'","ownerName":"' + shopperName + '"}';
        } else {
            return null;
        }
    }

    public static String getBillingAddress() {
        return '{"city":"Rotterdam","companyName":"","country":"NL","firstName":"","lastName":"","name":"Store in Rotterdam","postalCode":"3012 AH","region":"","street":"Van Oldenbarneveltplaats 10"}';
    }

    public static String getBrowserInfo() {
        return '{"acceptHeader":"*/*","colorDepth":30,"language":"en-US","javaEnabled":false,"screenHeight":982,"screenWidth":1512,"userAgent":"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36","timeZoneOffset":180}';
    }

    private static String mockPaymentMethodsSuccessfulResponse() {
        return '{"storedPaymentMethods":null,"paymentMethods":[{"type":"scheme","supportsRecurring":null,"paymentMethodData":null,"name":"Cards","inputDetails":null,"group_x":null,"fundingSource":null,"details":null,"configuration":null,"brands":["amex","bcmc","diners","discover","mc","visa"]}],"oneClickPaymentMethods":null,"groups":null}';
    }

    public static String mockPaymentsSuccessfulResponse(Id cartId) {
        return '{"additionalData":{"cvcResult":"1 Matches","fraudResultType":"GREEN","authCode":"090644","avsResult":"5 No AVS data provided","cardBin":"411111","fraudManualReview":"false","aliasType":"Default","paymentMethod":"visa","alias":"H167852639363479","paymentMethodVariant":"visa"},"fraudResult":{"accountScore":50,"results":[{"accountScore":0,"checkId":2,"name":"CardChunkUsage"},{"accountScore":0,"checkId":3,"name":"PaymentDetailUsage"},{"accountScore":0,"checkId":4,"name":"HolderNameUsage"}]},"pspReference":"RCD987QW9HXXGN82","resultCode":"Authorised","amount":{"currency":"' + ACTIVE_CURRENCY + '","value":49893},"merchantReference":"' + cartId + '","paymentMethod":{"brand":"visa","type":"scheme"}}';
    }

    public static String mockPaymentsNotAuthorizedResponse(Id cartId) {
        return '{"additionalData":{"cvcResult":"1 Matches","fraudResultType":"GREEN","authCode":"090644","avsResult":"5 No AVS data provided","cardBin":"411111","fraudManualReview":"false","aliasType":"Default","paymentMethod":"visa","alias":"H167852639363479","paymentMethodVariant":"visa"},"fraudResult":{"accountScore":50,"results":[{"accountScore":0,"checkId":2,"name":"CardChunkUsage"},{"accountScore":0,"checkId":3,"name":"PaymentDetailUsage"},{"accountScore":0,"checkId":4,"name":"HolderNameUsage"}]},"pspReference":"RCD987QW9HXXGN82","resultCode":"Refused","refusalReason":"Refused","amount":{"currency":"' + ACTIVE_CURRENCY + '","value":49893},"merchantReference":"' + cartId + '","paymentMethod":{"brand":"visa","type":"scheme"}}';
    }

    public static String mockWebhookRequest(String eventCode, String pspReference, String webCartId, Boolean success) {
        return '{"live": "false", "notificationItems": [{"NotificationRequestItem": {"additionalData": {"recurring.recurringDetailReference": "9915692881181044", "recurring.shopperReference": "YOUR_SHOPPER_REFERENCE"}, "amount": {"currency": "'+ ACTIVE_CURRENCY +'", "value": 1000}, "eventCode": "' + eventCode + '", "eventDate": "2021-01-01T01:00:00+01:00", "merchantAccountCode": "YOUR_MERCHANT_ACCOUNT", "merchantReference": "' + webCartId + '", "paymentMethod": "ach", "operations": ["CANCEL", "CAPTURE", "REFUND"], "pspReference": "' + pspReference + '", "reason": "null", "success": "' + success + '"}}]}';
    }

    private static String genericErrorResponse() {
        return '{"status": 400, "errorCode": "702", "message": "Empty input which would have resulted in a null result.", "errorType": "validation"}';
    }

    public static HttpResponse mockHttpResponse(String body, Integer code) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'text/json');
        res.setBody(body);
        res.setStatusCode(code);
        return res;
    }

    public static Object getStateData() {
        Map<String,Object> stateData = new Map<String,Object> {
            'details' => new Map<String,String>{
                'redirectResult' => 'eyJ0cmFuc1N0YXR1cyI6IlkifQ=='
            }
        };
        return stateData;
    }
}