/**
 * Created by daniloc on 22/11/2023.
 */

@IsTest
public class TestDataFactory {
    public static List<PaymentMethod> getMultiplePaymentMethods() {
        PaymentMethod idealPaymentMethod = PaymentMethod.getExample();
        idealPaymentMethod.type = 'ideal';
        PaymentMethod paypalPaymentMethod = PaymentMethod.getExample();
        paypalPaymentMethod.type = 'paypal';
        PaymentMethod cardPaymentMethod = PaymentMethod.getExample();
        cardPaymentMethod.type = AdyenConstants.CARD_PAYMENT_METHOD_TYPE;
        return new List<PaymentMethod>{cardPaymentMethod, idealPaymentMethod, paypalPaymentMethod};
    }

    // HTTP Mocks
    public class PaymentMethodsSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(mockPaymentMethodsSuccessfulResponse(), 200);
        }
    }

    public class PaymentMethodsErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            return mockHttpResponse(mockPaymentMethodsErrorResponse(), 400);
        }
    }

    private static String mockPaymentMethodsSuccessfulResponse() {
        return '{"storedPaymentMethods":null,"paymentMethods":[{"type":"scheme","supportsRecurring":null,"paymentMethodData":null,"name":"Cards","inputDetails":null,"group_x":null,"fundingSource":null,"details":null,"configuration":null,"brands":["amex","bcmc","diners","discover","mc","visa"]}],"oneClickPaymentMethods":null,"groups":null}';
    }

    private static String mockPaymentMethodsErrorResponse() {
        return '{"status": 400, "errorCode": "702", "message": "Empty input which would have resulted in a null result.", "errorType": "validation"}';
    }

    private static HttpResponse mockHttpResponse(String body, Integer code) {
        HttpResponse res = new HttpResponse();
        res.setHeader('Content-Type', 'text/json');
        res.setBody(body);
        res.setStatusCode(code);
        return res;
    }
}