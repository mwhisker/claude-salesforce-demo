export const NavigationMixin = jest.fn((Base) => {
    return class extends Base {
        navigate = jest.fn();
    };
});

export const CurrentPageReference = jest.fn();
