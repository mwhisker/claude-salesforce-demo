import { createElement } from "lwc";
import HelloWorld from "c/helloWorld";

describe("c-hello-world", () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
    });

    it("displays default greeting", () => {
        // Create component
        const element = createElement("c-hello-world", {
            is: HelloWorld
        });
        document.body.appendChild(element);

        // Query for rendered text
        const message = element.shadowRoot.querySelector("p");
        expect(message.textContent).toBe("Hello, World!");
    });

    it("updates greeting when input changes", async () => {
        // Create component
        const element = createElement("c-hello-world", {
            is: HelloWorld
        });
        document.body.appendChild(element);

        // Simulate user input
        const inputElement =
            element.shadowRoot.querySelector("lightning-input");
        inputElement.value = "Salesforce";
        inputElement.dispatchEvent(
            new CustomEvent("change", {
                detail: { value: "Salesforce" }
            })
        );

        // Wait for any asynchronous DOM updates
        await Promise.resolve();

        // Query for updated text
        const message = element.shadowRoot.querySelector("p");
        expect(message.textContent).toBe("Hello, Salesforce!");
    });
});
