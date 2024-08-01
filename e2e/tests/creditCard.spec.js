import { test } from "@playwright/test";
import {
	placeOrder,
	prepareOrder,
	selectCards,
	verifyOrderConfirmation,
	verifyOrderFailure,
} from "../utils/ScenarioHelper";
import {
	cancel3DSecure,
	fill3DSecureDetails,
	fillCardDetails,
} from "../utils/PaymentHelper";
import {
	cvc,
	expDate,
	masterCard3DS2,
	threeDSCorrectPassword,
	threeDSWrongPassword,
} from "../data/PaymentResources";

test.describe("Credit Card Payments", () => {
	test("with 3Ds2 should succeed with correct password", async ({ page }) => {
		await prepareOrder(page);

		await selectCards(page);
		await fillCardDetails(page, masterCard3DS2, expDate, cvc);
		await placeOrder(page);

		await fill3DSecureDetails(page, threeDSCorrectPassword);

		await verifyOrderConfirmation(page);
	});

	test("with 3Ds2 should fail with wrong password", async ({ page }) => {
		await prepareOrder(page);

		await selectCards(page);
		await fillCardDetails(page, masterCard3DS2, expDate, cvc);
		await placeOrder(page);

		await fill3DSecureDetails(page, threeDSWrongPassword);

		await verifyOrderFailure(page);
	});

	test("with 3Ds2 should be handled properly when 3Ds2 challenge is cancelled ", async ({
		page,
	}) => {
		await prepareOrder(page);

		await selectCards(page);
		await fillCardDetails(page, masterCard3DS2, expDate, cvc);
		await placeOrder(page);

		await cancel3DSecure(page);

		await verifyOrderFailure(page);
	});
});
