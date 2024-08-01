export const fillCardDetails = async (page, cardNumber, expDate, cvc) => {
	await page
		.frameLocator('iframe[title="Iframe for card number"]')
		.getByPlaceholder("5678 9012 3456")
		.click();
	await page
		.frameLocator('iframe[title="Iframe for card number"]')
		.getByPlaceholder("5678 9012 3456")
		.fill(cardNumber);
	await page
		.frameLocator('iframe[title="Iframe for card number"]')
		.getByPlaceholder("5678 9012 3456");
	await page
		.frameLocator('iframe[title="Iframe for expiry date"]')
		.getByPlaceholder("MM/YY")
		.fill(expDate);
	await page
		.frameLocator('iframe[title="Iframe for security code"]')
		.getByPlaceholder("digits")
		.fill(cvc);
	await page.getByPlaceholder("J. Smith").click();
	await page.getByPlaceholder("J. Smith").fill("John Doe");
};

export const fill3DSecureDetails = async (page, password) => {
	await page
		.frameLocator('iframe[name="threeDSIframe"]')
		.getByPlaceholder("enter the word 'password'")
		.click();
	await page
		.frameLocator('iframe[name="threeDSIframe"]')
		.getByPlaceholder("enter the word 'password'")
		.fill(password);
	await page
		.frameLocator('iframe[name="threeDSIframe"]')
		.getByRole("button", { name: "OK" })
		.click();
};

export const cancel3DSecure = async (page) => {
	await page
		.frameLocator('iframe[name="threeDSIframe"]')
		.getByRole("button", { name: "Cancel" })
		.click();
};
