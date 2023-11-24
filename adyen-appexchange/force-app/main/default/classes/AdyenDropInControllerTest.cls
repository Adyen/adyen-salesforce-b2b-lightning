/**
 * Created by daniloc on 22/11/2023.
 */
@IsTest
private class AdyenDropInControllerTest {
    @IsTest
    private static void fetchPaymentMethodsSuccessTest() {
        // given
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentMethodsSuccessMock());
        // when
        Test.startTest();
        PaymentMethodsResponse paymentMethodsResponse = (PaymentMethodsResponse)JSON.deserialize(AdyenDropInController.fetchPaymentMethods(AdyenConstants.DEFAULT_ADAPTER_NAME), PaymentMethodsResponse.class);
        Test.stopTest();
        // then
        Assert.isNotNull(paymentMethodsResponse);
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
        Test.setMock(HttpCalloutMock.class, new TestDataFactory.PaymentMethodsErrorMock());
        try { // when
            AdyenDropInController.fetchPaymentMethods(AdyenConstants.DEFAULT_ADAPTER_NAME);
            Assert.fail();
        } catch (Exception ex) { // then
            Assert.isInstanceOfType(ex, AuraHandledException.class);
        }
    }




}