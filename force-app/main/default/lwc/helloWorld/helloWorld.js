import { LightningElement } from "lwc";

export default class HelloWorld extends LightningElement {
    greeting = "World";

    get message() {
        return `Hello, ${this.greeting}!`;
    }

    handleInputChange(event) {
        this.greeting = event.target.value;
    }
}
