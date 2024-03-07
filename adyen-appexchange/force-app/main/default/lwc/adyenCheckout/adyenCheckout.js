import { api, wire, LightningElement } from 'lwc';
import adyenCheckoutCSS from '@salesforce/resourceUrl/AdyenCheckoutCSS';
import adyenCheckoutJS from '@salesforce/resourceUrl/AdyenCheckoutJS';
import fetchPaymentMethods from '@salesforce/apex/AdyenDropInController.fetchPaymentMethods';
import makePayment from '@salesforce/apex/AdyenDropInController.makePayment';
import makeDetailsCall from '@salesforce/apex/AdyenDropInController.makeDetailsCall';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { useCheckoutComponent, placeOrder } from 'commerce/checkoutApi';
import userLocale from '@salesforce/i18n/locale';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';

const CheckoutStage = {
    CHECK_VALIDITY_UPDATE: 'CHECK_VALIDITY_UPDATE',
    REPORT_VALIDITY_SAVE: 'REPORT_VALIDITY_SAVE',
    BEFORE_PAYMENT: 'BEFORE_PAYMENT',
    PAYMENT: 'PAYMENT',
    BEFORE_PLACE_ORDER: 'BEFORE_PLACE_ORDER',
    PLACE_ORDER: 'PLACE_ORDER'
};
export default class AdyenCheckoutComponent extends useCheckoutComponent(NavigationMixin(LightningElement)) {
    static renderMode = 'light';
    @api adyenAdapter
    @api adyenEnvironment;
    @api checkoutDetails;
    @api urlPath
    adyenCheckout;
    mountedDropIn;
    loading = true;
    error;
    dropInIsValid = false;
    paymentMethods;
    clientKey;
    cardData = { holderName: '', brand: '', bin: '', lastFourDigits: ''};
    resolvePayment;
    rejectPayment;
    redirectResult;
    notYetExecuted = true;


    @wire(CurrentPageReference)
    async wiredPagRef(currentPageReference) {
        if (currentPageReference && this.notYetExecuted) {
            this.notYetExecuted = false;
            try {
                this.redirectResult = currentPageReference.state?.redirectResult;
                if (this.redirectResult) {
                    this.adyenCheckout = await this.getAdyenCheckoutNoPaymentMethods();
                    await this.processDropInPayment();
                } else {
                    await this.constructAdyenCheckout();
                }
            } catch(ex) {
                this.handleComponentError(ex);
            }
        }
    }

    connectedCallback() {
        this.loading = true;
    }

    stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                return Promise.resolve(this.reportValidity());
            case CheckoutStage.PAYMENT:
                return this.processDropInPayment();
            default:
                return Promise.resolve(true);
        }
    }
    reportValidity() {
        const cardDataIsFilled = Object.values(this.cardData).every(property => {
            return typeof property === 'string' && property.length > 0;
        });
        if (!this.dropInIsValid || !cardDataIsFilled) {
            this.dispatchUpdateErrorAsync({
                groupId: 'Card details',
                type: '/commerce/errors/checkout-failure',
                exception: 'Card details must be filled in.',
            });
        }
        return cardDataIsFilled;
    }

    async constructAdyenCheckout() {
        try {
            this.adyenCheckout = await this.getAdyenCheckout();
            this.mountedDropIn = this.adyenCheckout.create('dropin').mount('#dropin-container');
        } catch (error) {
            this.handleComponentError(error);
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

    async getAdyenCheckoutNoPaymentMethods() {
        await this.loadAdyenScripts();
        return await AdyenCheckout(this.createConfigObject(null));
    }

    handleComponentError(error) {
        console.error(error);
        this.error = error;
    }

    createConfigObject(paymentMethods) {
        return {
            paymentMethodsResponse: paymentMethods,
            clientKey: this.clientKey,
            locale: userLocale,
            environment: this.adyenEnvironment,
            showPayButton: false,
            onSubmit: (state, dropin) => {
                if (state.isValid === false) {
                    throw new Error('invalid state');
                }
                this.mySubmit(state, dropin);
            },
            onAdditionalDetails: (state, dropin) => {
                if (state.isValid === false) {
                    throw new Error('invalid state');
                }
                this.myAdditionalDetails(state, dropin);
            },
            paymentMethodsConfiguration: {
                card: {
                    hasHolderName: true,
                    holderNameRequired: true,
                    hideCVC: false,
                    onFieldValid: (data) => {
                        this.cardData.lastFourDigits =  data.endDigits ? data.endDigits : this.cardData.lastFourDigits;
                        this.cardData.bin =  data.issuerBin ? String(data.issuerBin) : this.cardData.bin;
                    },
                    onChange: (data) => {
                        this.dropInIsValid = data.isValid;
                        const paymentMethod = data.data?.paymentMethod;
                        if (paymentMethod) {
                            this.cardData.holderName = paymentMethod.holderName ?  paymentMethod.holderName : this.cardData.holderName;
                            this.cardData.brand = paymentMethod.brand ? paymentMethod.brand : this.cardData.brand;
                        }
                    }
                }
            }
        };
    }

    async mySubmit(state, dropin) {
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
            await this.handleResponse(paymentResponse, dropin);
        } catch (error) {
            this.handleFailedPayment(JSON.stringify(error));
        } finally {
            this.loading = false;
        }
    }

    async myAdditionalDetails(state, dropin) {
        try {
            this.loading = true;
            const response = JSON.parse(await makeDetailsCall({stateData: state.data, adyenAdapterName: this.adyenAdapter}));
            await this.handleResponse(response, dropin);
        } catch (error) {
            this.handleFailedPayment(JSON.stringify(error));
        } finally {
            this.loading = false;
        }
    }

    processDropInPayment() {
        return new Promise((resolve, reject) => {
            this.resolvePayment = resolve;
            this.rejectPayment = reject;
            if (this.mountedDropIn) {
                this.mountedDropIn.submit();
            } else {
                this.adyenCheckout.submitDetails({data: {details: {redirectResult: this.redirectResult}}});
            }
        }).then(result => {
            return result;
        }).catch(error => {
            return error;
        });
    }

    async handleResponse(response, dropin) {
        if (response.action) {
            await dropin.handleAction(response.action);
        } else if (response.resultCode === 'AUTHORISED') {
            await this.handleSuccessfulPayment();
        } else {
            this.handleFailedPayment('not_authorized');
        }
    }

    async handleSuccessfulPayment() {
        if (this.mountedDropIn) {
            this.resolvePayment(true);
        } else {
            const placeOrderResult = await placeOrder();
            this.navigateToConfirmationPage(placeOrderResult);
        }
    }

    handleFailedPayment(errorMsg) {
        console.error('error payment', errorMsg);
        if (this.mountedDropIn) {
            this.dispatchUpdateErrorAsync({
                groupId: 'Payment processing',
                type: '/commerce/errors/checkout-failure',
                exception: 'Payment failed with: ' + errorMsg,
            });
            this.rejectPayment(false);
        } else {
            this.navigateToErrorPage(errorMsg);
        }
    }

    navigateToConfirmationPage(placeOrderResult) {
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

    navigateToErrorPage(errorMsg) {
        const errorPageRef = {
            type: 'comm__namedPage',
            attributes: {
                name: 'Error'
            }
        };
        errorPageRef.state = {
            paymentError: errorMsg
        };
        this[NavigationMixin.Navigate](errorPageRef);
    }
}