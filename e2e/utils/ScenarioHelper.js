import { expect } from "@playwright/test";

const login = async (page) => {
	await page.goto(`/${process.env.STORE_ID}`);
	await page.getByLabel("Username").click();
	await page.getByLabel("Username").fill(process.env.STORE_USERNAME);
	await page.getByLabel("Password").click();
	await page.getByLabel("Password").fill(process.env.STORE_PASSWORD);
	await page.getByRole("button", { name: "Log In" }).click();
};

const navigateToProductPage = async (page) => {
	await page.getByRole("link", { name: "Products" }).first().click();
	await page.getByLabel("Search Results").getByRole("link").first().click();
};

const addProductToCart = async (page, quantity = 1) => {
	await page.getByRole("textbox", { name: "QTY" }).fill(quantity.toString());
	await page.getByLabel("Add To Cart").click();
};

const navigateToCartAndCheckout = async (page) => {
	await page.goto(`/${process.env.STORE_ID}/cart`)
	await page.getByRole("button", { name: "Checkout" }).click();
};

const selectShippingAddress = async (page) => {
	await page
		.locator(".slds-spinner_container")
		.waitFor({ state: "attached", timeout: 15000 });
	await page.locator(".slds-spinner_container").isVisible();
	await page
		.locator(".slds-spinner_container")
		.waitFor({ state: "detached", timeout: 15000 });

	if (await page.getByRole("button", { name: "New Address" }).isVisible()) {
		await page.getByRole("group", { name: "Shipping" }).locator("span").click();
	}
};

export const prepareOrder = async (page, productQuantity) => {
	await login(page);
	await navigateToProductPage(page);
	await addProductToCart(page, productQuantity);
	await navigateToCartAndCheckout(page);
	await selectShippingAddress(page);
};

export const selectCards = async (page) => {
	await page.getByRole("radio", { name: "Cards" }).click();
};

const selectShippingMethod = async (page) => {
	await page.getByText("Ground Shipping").click();
};

export const placeOrder = async (page) => {
	await selectShippingMethod(page);
	await page.getByRole("button", { name: "Place Order" }).click();
};

export const verifyOrderConfirmation = async (page) => {
	await expect(
		await page.getByRole("heading", {
			name: "Thank you for your order!",
			timeout: 10000,
		})
	).toBeVisible();
};

export const verifyOrderFailure = async (page) => {
	await expect(
		await page.getByRole("heading", {
			name: "Something went wrong.",
			timeout: 10000,
		})
	).toBeVisible();
};
