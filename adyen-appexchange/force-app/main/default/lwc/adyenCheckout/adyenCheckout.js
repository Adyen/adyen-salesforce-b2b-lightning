/**
 * Created by daniloc on 21/11/2023.
 */

import {api, LightningElement} from 'lwc';
import adyenCheckoutCSS from '@salesforce/resourceUrl/AdyenCheckoutCSS';
import adyenCheckoutJS from '@salesforce/resourceUrl/AdyenCheckoutJS';
import fetchPaymentMethods from '@salesforce/apex/AdyenDropInController.fetchPaymentMethods';
import makePayment from '@salesforce/apex/AdyenDropInController.makePayment';
// import makeDetailsCall from '@salesforce/apex/AdyenDropInController.makeDetailsCall';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { useCheckoutComponent } from 'commerce/checkoutApi';
import userLocale from '@salesforce/i18n/locale';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AdyenCheckoutComponent extends useCheckoutComponent(NavigationMixin(LightningElement)) {
    static renderMode = 'light';
    loading = true;
    error = false;
    @api checkoutDetails;
    @api checkoutAddresses;
    @api adyenAdapter
    paymentMethods;
    clientKey;
    orderReferenceNumber;
    cardEndDigits;

    connectedCallback() {
        this.loading = true;
        this.fetchAdyenPaymentMethods();
    }

    async fetchAdyenPaymentMethods() {
        try {
            const paymentInfo = await fetchPaymentMethods({ adyenAdapterName: this.adyenAdapter });
            this.handlePaymentInfo(paymentInfo);
            await this.loadAdyenScripts();
            await this.mountAdyenDropIn();
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    handlePaymentInfo(paymentInfo) {
        this.paymentMethods = JSON.parse(paymentInfo.paymentMethodsResponse);
        this.clientKey = paymentInfo.clientKey;
    }

    async loadAdyenScripts() {
        await Promise.all([
            loadStyle(this, adyenCheckoutCSS),
            loadScript(this, adyenCheckoutJS),
        ]);
    }

    async mountAdyenDropIn() {
        const checkout = await AdyenCheckout(this.createConfigObject(this.paymentMethods));
        const dropin = checkout.create('dropin').mount('#dropin-container');
    }

    handleError(error) {
        console.error(error);
        this.error = error;
    }

    showConfirmationPage(placeOrderResult) {
        const orderPageRef = {
            type: 'comm__namedPage',
            attributes: {
                name: 'Order'
            }
        };
        orderPageRef.state = {
            orderNumber: placeOrderResult.orderReferenceNumber
        };
        this[NavigationMixin.Navigate](orderPageRef);
    }

    createConfigObject(paymentMethods) {
        return {
            paymentMethodsResponse: paymentMethods,
            clientKey: this.clientKey,
            locale: userLocale,
            environment: "test",
            onSubmit: async (state, dropin) => {
                try {
                    this.loading = true;
                    const paymentResponse = await makePayment({
                        paymentMethodType: state.data.paymentMethod.type,
                        paymentMethod: JSON.stringify(state.data.paymentMethod),
                        adyenAdapterName: this.adyenAdapter,
                        endDigits: this.cardEndDigits
                    });
                    if (paymentResponse) {
                        const placeOrderResult = await this.dispatchPlaceOrderAsync();
                        this.showConfirmationPage(placeOrderResult);
                    } else {
                        this.showToast('Not authorized', 'Payment was not authorized, try again', 'error');
                    }
                } catch (error) {
                    this.handleError(error);
                } finally {
                    this.loading = false;
                }
            },
            paymentMethodsConfiguration: {
                card: {
                    hasHolderName: true,
                    holderNameRequired: true,
                    hideCVC: false,
                    onFieldValid: (data) => {
                        this.cardEndDigits =  data.endDigits ? data.endDigits : this.cardEndDigits;
                    },
                }
            }
        };
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            variant: variant,
            message: message,
        });
        this.dispatchEvent(event);
    }
}