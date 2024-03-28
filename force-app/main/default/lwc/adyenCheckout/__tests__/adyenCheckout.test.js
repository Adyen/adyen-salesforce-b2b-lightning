import {createElement} from 'lwc';
// Mock Apex methods
jest.mock('@salesforce/apex/AdyenDropInController.fetchPaymentMethods', () => {
    return {
        default: jest.fn().mockResolvedValue({
            paymentMethodsResponse: '{"storedPaymentMethods":null,"paymentMethods":[{"type":"scheme","supportsRecurring":null,"paymentMethodData":null,"name":"Cards","inputDetails":null,"group_x":null,"fundingSource":null,"details":null,"configuration":null,"brands":["amex","bcmc","diners","discover","mc","visa"]}],"oneClickPaymentMethods":null,"groups":null}',
            clientKey: 'sampleClientKey'
        })
    };
}, { virtual: true });

describe('adyenCheckoutComponent', () => {
    it('loads the drop-in component after fetching payment methods', async () => {
        const element = createElement('c-adyen-checkout', {
            is: AdyenCheckoutComponent
        });

        document.body.appendChild(element);

        // Wait for async code to execute
        await flushPromises();

        // Assertions to check if drop-in component is loaded
        expect(element.error).toBe(false); // Add appropriate assertions here
    });
});
