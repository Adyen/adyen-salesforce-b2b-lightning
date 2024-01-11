import {api, wire, LightningElement} from 'lwc';
import adyenCheckoutCSS from '@salesforce/resourceUrl/AdyenCheckoutCSS';
import adyenCheckoutJS from '@salesforce/resourceUrl/AdyenCheckoutJS';
import fetchPaymentMethods from '@salesforce/apex/AdyenDropInController.fetchPaymentMethods';
import makePayment from '@salesforce/apex/AdyenDropInController.makePayment';
import makeDetailsCall from '@salesforce/apex/AdyenDropInController.makeDetailsCall';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { useCheckoutComponent } from 'commerce/checkoutApi';
import userLocale from '@salesforce/i18n/locale';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AdyenCheckoutComponent extends useCheckoutComponent(NavigationMixin(LightningElement)) {
    static renderMode = 'light';
    @api adyenAdapter
    @api adyenEnvironment;
    @api checkoutDetails;
    @api urlPath
    loading = true;
    error = false;
    detailsSubmitted = false;
    paymentMethods;
    clientKey;
    orderReferenceNumber;
    cardData = { holderName: '', brand: '', bin: '', lastFourDigits: ''};

    @wire(CurrentPageReference)
    async getStateParameters(currentPageReference) {
        if (currentPageReference) {
            const redirectResult = currentPageReference.state?.redirectResult;
            if (redirectResult && !this.detailsSubmitted) {
                this.detailsSubmitted = true;
                const checkout = await this.getAdyenCheckout();
                checkout.submitDetails({data: {details: {redirectResult}}});
            }
        }
    }

    connectedCallback() {
        this.loading = true;
        this.constructAdyenCheckout();
    }

    async constructAdyenCheckout() {
        try {
            const checkout = await this.getAdyenCheckout();
            checkout.create('dropin').mount('#dropin-container');
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async handlePaymentInfo() {
        const paymentInfo = await fetchPaymentMethods({ adyenAdapterName: this.adyenAdapter });
        this.paymentMethods = JSON.parse(paymentInfo.paymentMethodsResponse);
        this.clientKey = paymentInfo.clientKey;
    }

    async loadAdyenScripts() {
        await Promise.all([
            loadStyle(this, adyenCheckoutCSS),
            loadScript(this, adyenCheckoutJS),
        ]);
    }

    async getAdyenCheckout() {
        await Promise.all([
            this.loadAdyenScripts(),
            this.handlePaymentInfo()
        ]);
        return await AdyenCheckout(this.createConfigObject(this.paymentMethods));
    }

    handleError(error) {
        console.error(error);
        this.error = error;
    }

    createConfigObject(paymentMethods) {
        return {
            paymentMethodsResponse: paymentMethods,
            clientKey: this.clientKey,
            locale: userLocale,
            environment: this.adyenEnvironment,
            onSubmit: async (state, dropin) => {
                try {
                    this.loading = true;
                    const clientData = {
                        paymentMethodType: state.data.paymentMethod.type,
                        paymentMethod: JSON.stringify(state.data.paymentMethod),
                        adyenAdapterName: this.adyenAdapter,
                        browserInfo: JSON.stringify(state.data.browserInfo),
                        billingAddress: JSON.stringify(this.checkoutDetails.billingInfo.address),
                        cardData: this.cardData,
                        urlPath: this.urlPath
                    }
                    const paymentResponse = JSON.parse(await makePayment({clientDetails: clientData}));
                    if (paymentResponse.action) {
                        dropin.handleAction(paymentResponse.action);
                    } else if (paymentResponse.resultCode === 'AUTHORISED') {
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
            onAdditionalDetails: async (state, dropin) => {
                try {
                    this.loading = true;
                    const response = JSON.parse(await makeDetailsCall({stateData: state.data, adyenAdapterName: this.adyenAdapter}));
                    if (response.action) {
                        dropin.handleAction(response.action);
                    } else if (response.resultCode === 'AUTHORISED') {
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
                        this.cardData.lastFourDigits =  data.endDigits ? data.endDigits : this.cardData.lastFourDigits;
                        this.cardData.bin =  data.issuerBin ? data.issuerBin : this.cardData.bin;
                    },
                    onChange: (data) => {
                        const paymentMethod = data.data?.paymentMethod;
                        if (paymentMethod) {
                            this.cardData.holderName = paymentMethod.holderName ? paymentMethod.holderName : this.cardData.holderName;
                            this.cardData.brand = paymentMethod.brand ? paymentMethod.brand : this.cardData.brand;
                        }
                    }
                }
            }
        };
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

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            variant: variant,
            message: message,
        });
        this.dispatchEvent(event);
    }
}