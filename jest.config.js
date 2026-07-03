const { jestConfig } = require("@salesforce/sfdx-lwc-jest/config");

module.exports = {
    ...jestConfig,
    modulePathIgnorePatterns: ["<rootDir>/.localdevserver"],
    moduleNameMapper: {
        "^@salesforce/apex$": "<rootDir>/jest-mocks/apex",
        "^@salesforce/schema$": "<rootDir>/jest-mocks/schema",
        "^lightning/navigation$": "<rootDir>/jest-mocks/lightning/navigation",
        "^lightning/platformShowToastEvent$":
            "<rootDir>/jest-mocks/lightning/platformShowToastEvent"
    }
};
