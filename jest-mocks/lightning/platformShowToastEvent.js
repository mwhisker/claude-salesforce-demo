export default class ShowToastEvent extends CustomEvent {
    constructor(options) {
        super("lightning__showtoast", {
            composed: true,
            bubbles: true,
            detail: options
        });
    }
}
