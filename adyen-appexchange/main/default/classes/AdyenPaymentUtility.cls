public with sharing class AdyenPaymentUtility {

    public static final Set<String> threeDecimalCurrencies = new Set<String> {
        'BHD','IQD','JOD','KWD','LWD','OMR','TND'
    };
    public static final Set<String> zeroDecimalCurrencies  = new Set<String> {
        'CVE', 'DJF', 'GNF', 'IDR', 'JPY', 'KMF', 'KRW',
        'PYG', 'RWF', 'UGX', 'VND', 'VUV', 'XAF', 'XOF', 'XPF'
    };

    /**
    * Convert a request body from the adyen apex library into an api consumable json string
    * (strips the '_x' from attributes that would otherwise be Apex reserved keywords)
    *
    * @param input - the json string containing a *_x key
    * @return output - the same json string with the _x removed
    */
    public static String makeAdyenCompatible(String input) {
        Map<String, String> mapKeyToReplace = new Map<String, String> {
            'currency_x' => 'currency',
            'number_x' => 'number',
            'group_x' => 'group'
        };
        String output = input;
        for (String key : mapKeyToReplace.keySet()) {
            output = output.replace(key, mapKeyToReplace.get(key));
        }
        return output;
    }

    /**
    * Convert a response from adyen into an Adyen apex library friendly object
    * (adds the '_x' back into attributes that are apex keywords)
    *
    * @param input - the json string missing the *_x from its keys
    * @return output - the same json string with *_x added back in
    */
    public static String makeSalesforceCompatible(String input) {
        String output = input;
        Map<String, String> mapKeyToReplace = new Map<String, String>{
            'recurring.recurringDetailReference' => 'recurring_recurringDetailReference',
            'currency' => 'currency_x',
            'number' => 'number_x',
            'group' => 'group_x'
        };
        for (String key : mapKeyToReplace.keySet()) {
            output = output.replace(key, mapKeyToReplace.get(key));
        }
        return output;
    }

    /**
    * For generating payment tokens
    *
    * @param stringLength
    * @return a random number with stringLength characters
    */
    public static String getRandomNumber(Integer stringLength) {
        final Integer MAX = Integer.valueOf(Math.pow(10, stringLength) - 1);
        return String.valueOf(Math.round(Math.random() * MAX)).leftPad(stringLength, '0');
    }

    /**
    * Get the shopper reference from the card payment method.
    * - GatewayTokenDetails should be populated with the value from the Adyen tokenization response
    * - An encoded hash of the user's email
    */
    public static String getShopperReference(CardPaymentMethod cpm) {
        if (String.isNotEmpty(cpm.GatewayTokenDetails)) {
            return cpm.GatewayTokenDetails;
        }
        else return EncodingUtil.base64Encode(Crypto.generateDigest('SHA-256', Blob.valueOf(cpm.CardHolderName + cpm.Email)));
    }

    /**
    * Retrieve Payment Info.
    *
    * @param paymentId The Payment.Id value
    * @return a Payment sObject.
    */
    public static Payment retrievePayment(Id paymentId) {
        if (
            Schema.sObjectType.Payment.fields.Id.isAccessible() && 
            Schema.sObjectType.Payment.fields.GatewayRefNumber.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.GatewayRefNumber.isAccessible() &&
            Schema.sObjectType.Payment.fields.CurrencyIsoCode.isAccessible() && 
            Schema.sObjectType.OrderPaymentSummary.fields.FullName.isAccessible()
        ) {
            return [SELECT Id, GatewayRefNumber, PaymentAuthorization.GatewayRefNumber,
                        CurrencyIsoCode, OrderPaymentSummary.FullName
                    FROM Payment
                    WHERE Id = :paymentId
                    LIMIT 1];
        } else {
            return null;
        }
    }

    /**
    *  Retrieves custom meta data associated with Adyen (Endpoint info) pulls all fields.
    *
    *  @return Adyen_Adapter__mdt for the passed metadata type with all fields.
    */
    public static Adyen_Adapter__mdt retrieveGatewayMetadata(String metaType) {

        if(Test.isRunningTest()) {
            return new Adyen_Adapter__mdt(
                MasterLabel = 'AdyenDefault',
                Single_Currency_Code__c = 'USD',
                System_Integrator_Name__c = 'CAPGEMINI',
                Endpoint_Method__c = 'POST',
                Authorize_Endpoint__c = '/payments',
                Refund_Endpoint__c = '/{paymentPspReference}/refund',
                Capture_Endpoint__c = '/{paymentPspReference}/capture',
                Endpoint_Api_Version__c = '/v1'
            );
        } else if (
            Schema.sObjectType.Adyen_Adapter__mdt.fields.Developername.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.NamespacePrefix.isAccessible() &&
            Schema.sObjectType.Adyen_Adapter__mdt.fields.MasterLabel.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Capture_Endpoint__c.isAccessible() &&
            Schema.sObjectType.Adyen_Adapter__mdt.fields.Endpoint_Api_Version__c.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Endpoint_Method__c.isAccessible() &&
            Schema.sObjectType.Adyen_Adapter__mdt.fields.Endpoint_Path__c.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Merchant_Account__c.isAccessible() &&
            Schema.sObjectType.Adyen_Adapter__mdt.fields.System_Integrator_Name__c.isAccessible() && Schema.sObjectType.Adyen_Adapter__mdt.fields.Refund_Endpoint__c.isAccessible() &&
            Schema.sObjectType.Adyen_Adapter__mdt.fields.Authorize_Endpoint__c.isAccessible() &&
            Schema.sObjectType.Adyen_Adapter__mdt.fields.Single_Currency_Code__c.isAccessible() ) {
            return [SELECT Developername, NamespacePrefix, MasterLabel, Capture_Endpoint__c, Endpoint_Api_Version__c, 
                        System_Integrator_Name__c, Endpoint_Method__c, Endpoint_Path__c, Merchant_Account__c, 
                        Refund_Endpoint__c, Single_Currency_Code__c,
                        Authorize_Endpoint__c
                    FROM Adyen_Adapter__mdt
                    WHERE Developername = :metaType
                    LIMIT 1];
        } else {
            return null;
        }
    }

    /**
    * Retrieve PaymentAuthorizations Info.
    *
    * @param paymentAuthId The sObject PaymentAuthorizationId
    * @return a PaymentAuthorization sObject.
    */
    public static PaymentAuthorization retrievePaymentAuthorization(Id paymentAuthId) {
        if (
            Schema.sObjectType.PaymentAuthorization.fields.Id.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.PaymentAuthorizationNumber.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.GatewayRefNumber.isAccessible() &&
            Schema.sObjectType.PaymentAuthorization.fields.CurrencyIsoCode.isAccessible() &&
            Schema.sObjectType.PaymentGatewayLog.fields.GatewayRefNumber.isAccessible() &&
            Schema.sObjectType.OrderPaymentSummary.fields.Id.isAccessible() &&
            Schema.sObjectType.OrderPaymentSummary.fields.FullName.isAccessible()
        )
            return [SELECT Id, PaymentAuthorizationNumber, GatewayRefNumber,
                        OrderPaymentSummary.LastPaymentGatewayLog.GatewayRefNumber,
                        OrderPaymentSummary.Id,
                        OrderPaymentSummary.FullName, CurrencyIsoCode,
                        OrderPaymentSummary.OrderSummary.Id
                    FROM PaymentAuthorization
                    WHERE Id = :paymentAuthId
                    ORDER BY CreatedDate DESC
                    LIMIT 1];
        else {
            return null;
        }
    }

    /**
    * Check if Klarna Order.
    *
    * @param paymentAuthId The sObject PaymentAuthorizationId
    * @return Boolean denoting if the Authorization Id belongs to a Klarna Order.
    */
    public static Boolean checkIfKlarnaOrderFromAuthorization(PaymentAuthorization pa) {
        if (pa == null) {
            throw new AdyenAsyncAdapter.GatewayException('Payment Authorization Missing');
        }
        if (Test.isRunningTest()) {
            return true;
        }

        Boolean isKlarnaOrder = false;

        if (pa.OrderPaymentSummary?.OrderSummary?.Adyen_paymentMethod__c != null) {
            isKlarnaOrder = pa.OrderPaymentSummary.OrderSummary.Adyen_paymentMethod__c.containsIgnoreCase('klarna');
        }
        return isKlarnaOrder;
    }

    /**
    * For payment methods requiring Open Invoice data (e.g., Klarna), append invoice data.
    *
    * @param pa PaymentAuthorization
    * @return Map<String, Object> invoice data in key-value pairs
    */
    public static Map<String, Object> getInvoiceData(PaymentAuthorization pa) {
            // Get invoice id
            List<Id> invoiceIds = new List<Id>();
            if (pa?.OrderPaymentSummary?.OrderSummary?.Invoices != null) {
                for (Invoice i : pa?.OrderPaymentSummary?.OrderSummary?.Invoices) {
                    invoiceIds.add(i.Id);
                }
            }

            // Pull all InvoiceLines.  Send adjustments + charge vs shipping
            Integer invoiceLineCount = 0;
            Map<String, Object> additionalData = new Map<String, Object>();

            for (InvoiceLine invoiceLine : [SELECT Id, Product2.Name, Quantity, CurrencyIsoCode, ChargeAmount,
                                                ChargeTaxAmount, ChargeAmountWithTax, Type
                                            FROM InvoiceLine
                                            WHERE Type = 'Charge'
                                            AND InvoiceId IN :invoiceIds]) {

                Decimal itemAmount = Integer.valueOf(invoiceLine.ChargeAmount * AdyenPaymentUtility.getAmountMultiplier(pa.CurrencyIsoCode));
                Decimal itemVatAmount = Integer.valueOf(invoiceLine.ChargeTaxAmount * AdyenPaymentUtility.getAmountMultiplier(pa.CurrencyIsoCode));
                Decimal itemVatPercentage = invoiceLine.ChargeAmount / invoiceLine.ChargeTaxAmount;

                invoiceLineCount++;
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.currencyCode',          invoiceLine.CurrencyIsoCode);
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.description',           invoiceLine.Product2.Name);
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.itemAmount',            String.valueOf(itemAmount));
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.itemVatAmount',         String.valueOf(itemVatAmount));
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.itemVatPercentage',     String.valueOf(itemVatPercentage));
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.numberOfItems',         String.valueOf(Integer.valueOf(invoiceLine.Quantity)));
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.productUrl',            '');
                additionalData.put('openinvoicedata.line' + invoiceLineCount + '.imageUrl',              '');
            }
            additionalData.put('openinvoicedata.numberOfLines', invoiceLineCount);
            return additionalData;
    }

    /**
     * Retrieve apex adapter id from the gateway reference number.
     *
     * @param gatewayRefNumber original payment gatewayrefnumber as recieved in the notification
     * @return apexclass id for the payment gateway adapter.
     */
    public static String retrieveApexAdapterId(String gatewayRefNumber) {
        String apexAdapterId = null;
        
        // Prioritize the payment authorization record if it exists
        for (PaymentAuthorization paymentAuthorization : [SELECT PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id
                                                         FROM PaymentAuthorization 
                                                         WHERE GatewayRefNumber = :gatewayRefNumber]) {
            if (paymentAuthorization.PaymentGateway?.PaymentGatewayProvider?.ApexAdapter != null)
                apexAdapterId = paymentAuthorization.PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id;
        }

        // Fall back to a payment record for pre-captured transactions
        if (apexAdapterId == null) {
            for (Payment payment : [SELECT PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id
                                   FROM Payment
                                   WHERE GatewayRefNumber = :gatewayRefNumber]) {
                if (payment.PaymentGateway?.PaymentGatewayProvider?.ApexAdapter != null)
                    apexAdapterId = payment.PaymentGateway.PaymentGatewayProvider.ApexAdapter.Id;
            }
        }
         return apexAdapterId;
    }

    /**
     * Retrieve apex id from the class name and namespaceprefix.
     *
     * @param className The Class Name
     * @param namespace Namespace of the current class
     * @return apexclass id.
     */
    public static String retrieveApexClassId(String className, String namespace) {
        return [SELECT Id FROM ApexClass WHERE Name = :className AND NamespacePrefix = :namespace LIMIT 1]?.Id;
    }

    public static Integer getAmountMultiplier(String currencyCode) {
        if (threeDecimalCurrencies.contains(currencyCode)) {
            return 1000;
        }
        if (zeroDecimalCurrencies.contains(currencyCode)) {
            return 1;
        }
        return 100;
    }

    /**
     * Looks for the Gateway ref number on the Payment record passed in. If not found gets its from
     * the LastPaymentGateway log on the OrderPaymentSummary record.
     *
     * @param payment the Payment sObject.
     * @return the GatewayRefNumber for the request.
     */
    public static String getRefundGatewayRefNumber(Payment payment) {
        if (payment == null) {
            throw new AdyenAsyncAdapter.GatewayException('Payment Info Missing');
        }
        return payment.PaymentAuthorization?.GatewayRefNumber != null ? payment.PaymentAuthorization.GatewayRefNumber : payment.GatewayRefNumber;
    }

    /**
    * Looks for the Gateway ref number on the PaymentAuthorization record passed in. If not found gets its from
    * the LastPaymentGateway log on the OrderPaymentSummary record.
    *
    * @param pa  The PaymentAuthorization sObject
    * @return the GatewayRefNumber for the request.
    * @see https://ca-test.adyen.com/ca/ca/accounts/showTx.shtml?pspReference=852588546520527A&txType=Payment
    */
    public static String getCaptureGatewayRefNumber(PaymentAuthorization pa) {
        if (pa == null) {
            throw new AdyenAsyncAdapter.GatewayException('Payment Authorization Missing');
        }
        return pa.GatewayRefNumber != null ? pa.GatewayRefNumber : pa.OrderPaymentSummary?.LastPaymentGatewayLog?.GatewayRefNumber;
    }

    /**
    * Add application information to the webservice request
    *
    * @return application information map for the request.
    */
    public static ApplicationInfo getApplicationInfo(String integratorName) {

        ApplicationInfo info = new ApplicationInfo();

        CommonField merchantApplication = new CommonField();
        merchantApplication.name = 'AdyenSOM';
        merchantApplication.version = '1.0';
        info.merchantApplication = merchantApplication;

        ExternalPlatform exPlatform = new ExternalPlatform();
        exPlatform.name = 'Salesforce Order Management';
        exPlatform.version = '2020_winter';
        exPlatform.integrator = integratorName;
        info.externalPlatform = exPlatform;
        return info;
    }

    /**
    * Create a modification request by populating required properties (payment/refund)
    *
    * @return CheckoutModificationRequest to send to Adyen.
    */
    public static CheckoutModificationRequest createModificationRequest(CommercePayments.RequestType paymentType, String currencyCode, Double amount, String pspReference, String merchantAccount) {
       CheckoutModificationRequest modRequest;
       if (paymentType == CommercePayments.RequestType.Capture) {
         modRequest = new CheckoutCaptureRequest();
       } else if (paymentType == CommercePayments.RequestType.ReferencedRefund) {
         modRequest = new CheckoutRefundRequest();
       }
       modRequest.setReference(AdyenPaymentUtility.getRandomNumber(16));
       modRequest.setMerchantAccount(merchantAccount);
       Amount requestAmount = new Amount();
       requestAmount.value = (amount * AdyenPaymentUtility.getAmountMultiplier(currencyCode)).longValue();
       requestAmount.currency_x = currencyCode;
       modRequest.setAmount(requestAmount);
       return modRequest;
    }

    /**
    * Send modification request (payment/refund) to Adyen platform
    *
    * @return response from adyen platform.
    */
    public static HttpResponse sendModificationRequest(CheckoutModificationRequest modRequest, Adyen_Adapter__mdt adyenAdapterMdt, String endPoint) {
        CheckoutModificationResponse adyenResponse;
        String body = AdyenPaymentUtility.makeAdyenCompatible(JSON.serialize(modRequest));
        AdyenService client = new AdyenService(adyenAdapterMdt);
        client.setEndpoint(endPoint);
        client.setBody(body);
        HttpResponse response = client.execute();
        return response;
    }
}