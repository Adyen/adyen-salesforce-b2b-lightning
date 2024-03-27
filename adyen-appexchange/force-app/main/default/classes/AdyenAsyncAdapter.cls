/**
 *  This adapter is called by the Payment Gateway.
 *  The http calls are delegated to the AdyenPaymentHelper Class.
 *
 *  This will process a POST-AUTHORIZE Request.
 *
 *  @see AdyenPaymentHelper
 */
global with sharing class AdyenAsyncAdapter implements CommercePayments.PaymentGatewayAdapter {

    global AdyenAsyncAdapter() {}
  
   /**
    * The entry point for processing payment requests. Returns the response from the payment gateway.
    * Accepts the gateway context request and handover the operation to AdyenPaymentHelper to call the appropriate capture or refund operation.
    *
    * @param   paymentGatewayContext from Salesforce
    * @return  CommercePayments.GatewayResponse
    */
    global CommercePayments.GatewayResponse processRequest(CommercePayments.PaymentGatewayContext paymentGatewayContext) {
        return AdyenPaymentHelper.handleFulfillmentOrderStatusChange(paymentGatewayContext);
    }

    public class GatewayException extends Exception {}
}