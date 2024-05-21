import { api, wire, LightningElement } from 'lwc';
import adyenCheckoutCSS from '@salesforce/resourceUrl/AdyenCheckoutCSS';
import adyenCheckoutJS from '@salesforce/resourceUrl/AdyenCheckoutJS';
import { paymentMethodMockResponse } from './mocks';
import fetchPaymentMethods from '@salesforce/apex/AdyenDropInController.fetchPaymentMethods';
import makePayment from '@salesforce/apex/AdyenDropInController.makePayment';
import makeDetailsCall from '@salesforce/apex/AdyenDropInController.makeDetailsCall';
import getClientKey from '@salesforce/apex/AdyenDropInController.getMetadataClientKey';
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { useCheckoutComponent, placeOrder } from 'commerce/checkoutApi';
import userLocale from '@salesforce/i18n/locale';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import paymentNotAuthorized from "@salesforce/label/c.Payment_not_authorized";
import missingDetails from "@salesforce/label/c.Details_Missing_or_Incorrect";

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
    adyenCheckout;
    mountedDropIn;
    loading = true;
    error;
    dropInIsValid = false;
    paymentMethods;
    clientKey;
    cardData = { holderName: '', brand: '', bin: '', lastFourDigits: '' };
    resolvePayment;
    rejectPayment;
    redirectResult;
    notYetExecuted = true;
    labels = { paymentNotAuthorized, missingDetails };
    pageRef;

    get isInBuilderMode() {
        return this.pageRef?.state?.view === "editor";
    }

    @wire(CurrentPageReference)
    async wiredPagRef(currentPageReference) {
        if (currentPageReference && this.notYetExecuted) {
            this.notYetExecuted = false;
            this.pageRef = currentPageReference;
            try {
                this.redirectResult = currentPageReference.state?.redirectResult;
                if (this.redirectResult) {
                    this.adyenCheckout = await this.getAdyenCheckoutNoPaymentMethods();
                    await this.processDropInPayment();
                } else {
                    await this.constructAdyenCheckout();
                }
            } catch (ex) {
                this.handleError(ex);
            }
        }
    }

    connectedCallback() {
        this.loading = true;
        this.clearErrorMessages();
    }

    stageAction(checkoutStage) {
        switch (checkoutStage) {
            case CheckoutStage.CHECK_VALIDITY_UPDATE:
                return Promise.resolve(this.checkValidity());
            case CheckoutStage.REPORT_VALIDITY_SAVE:
                return Promise.resolve(this.reportValidity());
            case CheckoutStage.PAYMENT:
                return this.processDropInPayment();
            default:
                return Promise.resolve(true);
        }
    }

    checkValidity() {
        this.clearErrorMessages();
        return this.dropInIsValid;
    }

    reportValidity() {
        if (!this.dropInIsValid) {
            this.dispatchUpdateErrorAsync({
                groupId: 'CardDetails',
                type: '/commerce/errors/checkout-failure',
                exception: this.labels.missingDetails,
            });
        }
        return this.dropInIsValid;
    }

    async constructAdyenCheckout() {
        try {
            this.adyenCheckout = await this.getAdyenCheckout();
            this.mountedDropIn = this.adyenCheckout.create('dropin').mount('#dropin-container');
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async getAdyenCheckout() {
        await Promise.all([
            this.loadAdyenScripts(),
            this.fetchClientKey(),
            this.fetchPaymentMethods()
        ]);
        return await AdyenCheckout(this.createConfigObject(this.paymentMethods));
    }

    async fetchClientKey() {
        this.clientKey = await getClientKey({ adyenAdapterName: this.adyenAdapter });
    }

    async fetchPaymentMethods() {
        const paymentMethodsResp = this.isInBuilderMode ? paymentMethodMockResponse : await fetchPaymentMethods({ adyenAdapterName: this.adyenAdapter });
        if (!paymentMethodsResp) {
            throw new Error('Failed to load payment methods');
        }
        this.paymentMethods = JSON.parse(paymentMethodsResp);
    }

    async loadAdyenScripts() {
        await Promise.all([
            loadStyle(this, adyenCheckoutCSS),
            loadScript(this, adyenCheckoutJS),
        ]);
    }

    async getAdyenCheckoutNoPaymentMethods() {
        await this.loadAdyenScripts();
        return await AdyenCheckout(this.createConfigObject(null));
    }

    handleError(error) {
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
            onChange: (state) => {
                this.dropInIsValid = state.isValid;
            },
            onError: (error) => {
                this.handleError(error);
            },
            paymentMethodsConfiguration: {
                card: {
                    hasHolderName: true,
                    holderNameRequired: true,
                    hideCVC: false,
                    onFieldValid: (data) => {
                        this.cardData.lastFourDigits = data.endDigits ? data.endDigits : this.cardData.lastFourDigits;
                        this.cardData.bin = data.issuerBin ? String(data.issuerBin) : this.cardData.bin;
                    },
                    onChange: (data) => {
                        this.dropInIsValid = data.isValid;
                        const paymentMethod = data.data?.paymentMethod;
                        if (paymentMethod) {
                            this.cardData.holderName = paymentMethod.holderName ? paymentMethod.holderName : this.cardData.holderName;
                            this.cardData.brand = paymentMethod.brand ? paymentMethod.brand : this.cardData.brand;
                        }
                    }
                },
                ach: {
                    billingAddressRequired: false
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
                cardData: this.cardData
            }
            const paymentResponse = await makePayment({ clientDetails: clientData });
            await this.handleResponse(paymentResponse, dropin);
        } catch (error) {
            this.handleError(error);
        } finally {
            this.loading = false;
        }
    }

    async myAdditionalDetails(state, dropin) {
        try {
            this.loading = true;
            const response = await makeDetailsCall({ stateData: state.data, adyenAdapterName: this.adyenAdapter });
            await this.handleResponse(response, dropin);
        } catch (error) {
            this.handleError(error);
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
                this.adyenCheckout.submitDetails({ data: { details: { redirectResult: this.redirectResult } } });
            }
        }).then(result => {
            return result;
        }).catch(error => {
            return error;
        });
    }

    async handleResponse(response, dropin) {
        if (!response) {
            throw new Error('Failed to process payment');
        }
        if (response.action) {
            await dropin.handleAction(JSON.parse(response.action));
        } else if (response.paymentSuccessful) {
            await this.handleSuccessfulPayment();
        } else {
            await this.handleFailedPayment('not_authorized');
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

    async handleFailedPayment(errorMsg) {
        if (this.mountedDropIn) {
            this.dispatchUpdateErrorAsync({
                groupId: 'PaymentProcessing',
                type: '/commerce/errors/checkout-failure',
                exception: this.labels.paymentNotAuthorized,
            });
            this.rejectPayment(false);
            this.remountDropIn();
        } else {
            this.navigateToErrorPage(errorMsg);
        }
    }

    remountDropIn() {
        this.mountedDropIn.unmount();
        this.mountedDropIn = this.adyenCheckout.create('dropin').mount('#dropin-container');
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

    clearErrorMessages() {
        this.dispatchUpdateErrorAsync({
            groupId: 'CardDetails'
        });
        this.dispatchUpdateErrorAsync({
            groupId: 'PaymentProcessing'
        });
    }
}