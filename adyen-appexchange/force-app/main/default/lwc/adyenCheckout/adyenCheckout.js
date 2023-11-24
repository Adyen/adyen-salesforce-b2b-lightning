/**
 * Created by daniloc on 21/11/2023.
 */

import {api, LightningElement} from 'lwc';
import adyenCheckoutCSS from '@salesforce/resourceUrl/AdyenCheckoutCSS';
import adyenCheckoutJS from '@salesforce/resourceUrl/AdyenCheckoutJS';
import fetchPaymentMethods from "@salesforce/apex/AdyenDropInController.fetchPaymentMethods";
import { loadStyle, loadScript } from 'lightning/platformResourceLoader';
import { useCheckoutComponent } from 'commerce/checkoutApi';

export default class AdyenCheckoutComponent extends useCheckoutComponent(LightningElement) {
    static renderMode = 'light';
    loading = true;
    error = false;
    @api checkoutDetails;
    @api checkoutAddresses;
    @api adyenAdapter
    paymentMethods;
    connectedCallback() {
        fetchPaymentMethods({adyenAdapterName: this.adyenAdapter}).then((result) => {
            console.log('Result from fetch payment methods');
            console.log(JSON.stringify(result));
            this.paymentMethods = JSON.parse(result);
            Promise.all([
                loadStyle(this, adyenCheckoutCSS),
                loadScript(this, adyenCheckoutJS),
            ]).then(() => {
                console.log('All scripts loaded');
                try {
                    AdyenCheckout(this.createConfigObject(this.paymentMethods)).then( checkout => {
                        console.log('Result from checkout init')
                        console.log(checkout);
                        // Create an instance of Drop-in and mount it to the container you created.
                        checkout.create('dropin').mount('#dropin-container');
                    }).catch(error => {
                        console.error('Error from checkout init')
                        console.error(error);
                        this.error = error;
                    });
                } catch (error) {
                    console.error('Error from while mounting the drop in');
                    console.error(JSON.stringify(error));
                    this.error = error;
                }
            }).catch((error) => {
                console.error('Error from loading scripts');
                console.error(JSON.stringify(error));
                this.error = error;
            });
        }).catch((error) => {
            console.error('Error from fetch payment methods');
            console.error(JSON.stringify(error));
            this.error = error;
        }).finally(() => {
            this.loading = false;
        });
    }
}