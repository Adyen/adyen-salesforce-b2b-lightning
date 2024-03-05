@IsTest
public without sharing class TestDataFactory {
    public static final String ACTIVE_CURRENCY = [SELECT IsoCode FROM CurrencyType WHERE IsActive = TRUE LIMIT 1].IsoCode;

    public static ClientDetails createClientDetails() {
        ClientDetails clientDetails = new ClientDetails();
        clientDetails.paymentMethodType = AdyenB2BConstants.CARD_PAYMENT_METHOD_TYPE;
        clientDetails.paymentMethod = TestDataFactory.getPaymentMethodBody(clientDetails.paymentMethodType, 'Tester');
        clientDetails.urlPath = '/checkout';
        clientDetails.billingAddress = TestDataFactory.getBillingAddress();
        clientDetails.browserInfo = TestDataFactory.getBrowserInfo();
        clientDetails.adyenAdapterName = AdyenConstants.DEFAULT_ADAPTER_NAME;

        ClientDetails.CardData cardData = new ClientDetails.CardData();
        cardData.brand = 'amex';
        cardData.holderName = 'Danilo Cardoso';
        cardData.bin = '123456';
        cardData.lastFourDigits = '4321';
        clientDetails.cardData = cardData;

        return clientDetails;
    }

    public static WebStore setUpWebStore(Decimal unitPrice, String currencyIsoCode) {
        WebStore testWebStore = new WebStore(Name = 'TestWebStore', DefaultLanguage = 'en_US');
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

        User thisUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId()];
        System.runAs (thisUser) {
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

        PermissionSetAssignment permissionSetAssignment = new PermissionSetAssignment();
        permissionSetAssignment.AssigneeId = buyerUser.Id;
        permissionSetAssignment.PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'B2BBuyer'].Id;
        insert permissionSetAssignment;
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

    public static String getPaymentMethodBody(String type, String name) {
        return '{"type":"' + type + '","holderName":"' + name + '","encryptedCardNumber":"eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZDQkMtSFM1MTIiLCJ2ZXJzaW9uIjoiMSJ9.LSQCdHzOCtMV5w1FYF4OXG2TBY5kSSja5wdqvrti-i9SiO7r2FIOr2h9OQFtocfOblhO_oFQHj6i2hseY6Ug9tMGvPc_XwwuTLnx3nOHfSInRF26P6gxeNviXr2V3N41kL6Z3xsI_Za--AeR2PMtggieBZ2efwjNqICaLUl9x7cBb0ov89Os4yl1e9OBgZQDZvWaMfm9UEebuz-wbSqrsO-rzprCAlZ-HeHeKqrflJ9f3PVFuPl0p28T0v9rP8tS5HhG0jrqXKz53bRO_JsmBhvaT9HOT_Xmt9PU6gEPmsZvwgICPMTeYYwUwlHzW_6zNrnoobtw5dxRGlnewdI7Gw.CULhhAX3a9eR1hK6La3_WA.uvMuxIfmMV11QvdCokF8Gv8I2D4dyFELZmIqrtD2CC5fWRjAtfA4jKHshIHTDEyD08cy-6OaqPVvcakGzrplars5Hbr-4TQ4YRL7k_DLhWfGmPPfYv4MFkuOt5k1moT1r4ZSJX7W99-lERmZEnCon3z7Fvc0zQ9o14ow8FhgMdQ4ZrciiQPTAp6RKguye2sZKhmr96dsaWmSeLS_Bw9wvDaWYzkEIT072U41Ym_eZQClFdBaw6O90pSjZHKZtAMJDk41pAu4U1fnHSJfI2e5Zf1MGPtfr2PhI7HsJheTuSTQWcDkJRy7BlIMyzIk2qSh0X0q-FADsGJSNPPc86otA8UFrU7nlbPNAy79YVT3rIUU99JvhAJ3bKUfuTmflHGNMqkleKrNlRGk1yROLU7YQTlR-hLsCfqYUZFpBy471LasPVqKv52mEoG74xKZ4cZ6P8rSDssk5JKVwoqsiqVHmDgSupUBUdXJ-s2R-XItVS6pDdhdPeYDKgsjGV7du1w5CKTMfrkA2EaaAZdAy-l-cU4ORTjlwomIHsOp5VU6RzpiNnSabUZX2160IJ1IHYC_ulY32RCm7JG0HuDLx1rhhjo0sJ1Ost-TS9NDWACXENEVf65D_B_-lzz8_KvTN6cYVvIbENzRnM0Oras3uQ8-kg.j_9F5CcjtYZuzABBz1z9kMJnpa2aMsVhcJAhz84-JWs","encryptedExpiryMonth":"eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZDQkMtSFM1MTIiLCJ2ZXJzaW9uIjoiMSJ9.CSHqPZ1d2UhLV5zYOl8NpcNVqYRTE4OxHSTNkRtiebQo33sxODf64DiY1zD0DCAiAU-DVkZ4rK9IAJFSPwDzGYhFOmhGcNp4BGn-j__I1Eun-G-muHR6hCqvnuSkBFY5BWZI3IjMjDsr58QAYdLWyO-FOe3Rr7-DC7JjG1mgTspvhoywYgcijhd9TKJogZMjW6x4Pn4M8XPOsdRA-dFATgZfQn6B9aRseluhGDvFefwI3DxJlObLHNCx3GpTvccsCJ-xX_WWrKqhK1RJAG0UgzSJ5XdwoSjDggwlYd6YJN_BAB1fVBEuj4cvxmbmtasolX4gjIUu9y8mrKacvjaNCA.IjkzRFZpwW_djlgAPrjIKQ.rvSe6-ZK51jm4E86yzP_k-9b-o88nngmHRXNKPTr_do_30Yr584BUpGNthHt7gijMuejvaOpDF4avPWVHKr8-A.1CuRRtBeP5CdN4koqIAhVuZyNWIPDeV34qKD_I9POKM","encryptedExpiryYear":"eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZDQkMtSFM1MTIiLCJ2ZXJzaW9uIjoiMSJ9.mZwyPrGtz92r2W6Wo8PRJ_VhQQLk78xcXOy-NvOOZGSk6H3PfNxvbOGzAtW8-JBjjiUwG78CAeZeoikS1YWC1iJsTUUOJlCLhW-CdBM_Ljrw2U169jS0f09X7VaHcHC--P0vmeEL8wLgiSFnt8v9zGFeI2CX8hExRvna2ZmtfI7YG5sZwqnf9yr5JSgeTScSy6U9rc1Gpii1gnbu0HEslCehDDJrQSoO9GbHYPeXTdkHS3tjHCnPTsXKC3OoSiIYSf-CAGi_yZbdNTRIk3U8SM3t-XeYUwrT10sRKyA6BSkArkfbj5mtchmn-gfFYvW_3kIaN4FITK09mv0jU_NPdA.4BOM4SxA4J-EWLh9kQorhg.CJh3AqRrUCwEMeOOQamxSBwM04UO0mf36SyIjWOFKn6dItmWsf2WOyMOJNSrHAwu2eeDANa09bKx83ONiEFVFw.IYSIjCROtLmgCJ1Aily8W5XEO8xpIrUfhYZiJyErYmA","encryptedSecurityCode":"eyJhbGciOiJSU0EtT0FFUCIsImVuYyI6IkEyNTZDQkMtSFM1MTIiLCJ2ZXJzaW9uIjoiMSJ9.PZLiL3jFGZu6UaU4kc47LB-eO6DDR850J3cdI0etbt5DW6cZiyTNUjaU_I7zdLc2Ohhcb8i20PrlbVylKQ6Nkh6xG82JGB3tQAP4ZvNjqWQi-z3jyCeyOJdX0pBV2gcmUoCrdj6X9Lj-YD512xtA99S-_h3vRCI3C6pmTVxloimO5Cl5NtwXX_2KSpQmYxznRUAfXCkv7lxFO6kFvhRaATAExXNxCTiQ1PqnxGc4_X_-wEoR91gwSRAKeRhtCiGk0mhuc7WK9ITRLp8_omRPEgl9H1K6X0ZySMVSWfyfgFxMl_vGfNCnh51msKwGOycdFFWQ4AgMXw4BZIA4Bjfr1g.XJ-NPL7hif8_5NGFyqClkg.iJomJZ0FhPw99KxngN8G7KErNliug6K-8Y6vbu0TLhZK9V8Stu9m_ETB7KrknVrR_iwwFZrLKpNaXE0pX4KDJfacfuwiNZcn_OAj0j5-U1uBI3EkpblJ552q3HPEMMrT3tg-JLOy3w1SlY2vF7h9xO2phOtitvnMfx9q7VNp-01XXYAyS-EIBHAMluPePfH10aVdRykIkgGDqgs1csI00rftKGkDrXY7ctX3Atrq7ilXF0V133W_OQ-AEuubq4PMsCv22CBfR0XZviefiT-sQKDTt14PtjLfvKthz3SVFLtufWA_lmx-dTVwupaKVJc7Ju9L4jljowMMaavLWDEsM8eVuqeZUwkt6gp1uykfmTb0jmYPcgxm41pZGV7ubTGUfVmiTM_r-6-bS_exu_irRsYXSfP51c8rq0_cX3dx5GwpO3nbZ8IFUu2f4i8J2zOCMucFXJ8aGh6qQqRnY_3MKuZW2tlTxi515g1r6gUMO-9lFrGQNuRd1GhtgDiZz2Y1C8vcj3VIRhLTZ7lQFSBzAg.5ZSCskD3rdpKgbZXtm2a8AsTR8yvzFVwqBxxN9tXAYU","brand":"visa","checkoutAttemptId":"aea98b82-50d6-4a41-8273-078f6c1ee8031701869720354D0672D821ECEC5B2C75247B9691E8A3959332F82E6E0E814870B8ACB901B33D1"}';
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

    private static String mockPaymentsSuccessfulResponse(Id cartId) {
        return '{"additionalData":{"cvcResult":"1 Matches","fraudResultType":"GREEN","authCode":"090644","avsResult":"5 No AVS data provided","cardBin":"411111","fraudManualReview":"false","aliasType":"Default","paymentMethod":"visa","alias":"H167852639363479","paymentMethodVariant":"visa"},"fraudResult":{"accountScore":50,"results":[{"accountScore":0,"checkId":2,"name":"CardChunkUsage"},{"accountScore":0,"checkId":3,"name":"PaymentDetailUsage"},{"accountScore":0,"checkId":4,"name":"HolderNameUsage"}]},"pspReference":"RCD987QW9HXXGN82","resultCode":"Authorised","amount":{"currency":"EUR","value":49893},"merchantReference":"' + cartId + '","paymentMethod":{"brand":"visa","type":"scheme"}}';
    }

    public static String mockWebhookRequest(String eventCode, String pspReference, String webCartId, Boolean success) {
        return '{"live": "false", "notificationItems": [{"NotificationRequestItem": {"additionalData": {"recurring.recurringDetailReference": "9915692881181044", "recurring.shopperReference": "YOUR_SHOPPER_REFERENCE"}, "amount": {"currency": "EUR", "value": 1000}, "eventCode": "' + eventCode + '", "eventDate": "2021-01-01T01:00:00+01:00", "merchantAccountCode": "YOUR_MERCHANT_ACCOUNT", "merchantReference": "' + webCartId + '", "paymentMethod": "ach", "operations": ["CANCEL", "CAPTURE", "REFUND"], "pspReference": "' + pspReference + '", "reason": "null", "success": "' + success + '"}}]}';
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