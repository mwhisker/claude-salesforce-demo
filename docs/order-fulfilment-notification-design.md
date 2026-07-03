# Order Fulfilment Notification Automation Design

## Executive Summary

This document describes the automation added to notify internal teams (fulfilment and account management) via a templated email whenever an Order reaches the **Fulfilment** stage. It closes [#1](https://github.com/mwhisker/claude-salesforce-demo/issues/1).

> **Note:** This is a demo implementation intended to illustrate an AI-assisted workflow for designing and shipping a Salesforce automation end-to-end. Recipient addresses, field labels, and thresholds are placeholders and should be adapted to a real org's requirements before production use.

---

## Problem Statement

There was no way to track when an Order reached the fulfilment stage, and no automated notification was sent to relevant internal parties (fulfilment team, account management) when that happened.

## Solution Overview

1. **Tracking fields on `Order`**
    - `Fulfillment_Status__c` (Picklist: `Pending`, `Processing`, `Fulfilled`, `Cancelled`) — tracks the current fulfilment stage of the order.
    - `Fulfillment_Notification_Sent__c` (Checkbox, default `false`) — guards against duplicate notifications being sent for the same order.

2. **Email Template**
    - `OrderNotifications/Order_Fulfilment_Notification` — a text email template that summarizes the order number, account, amount, and fulfilment status.

3. **Email Alert**
    - `Order.Order_Fulfilment_Notification` (Workflow Email Alert) — references the email template above and sends to the internal fulfilment team and account management distribution addresses.

4. **Record-Triggered Flow**
    - `Order_Fulfilment_Notification` — an after-save, record-triggered flow on `Order` that fires when `Fulfillment_Status__c` changes to `Fulfilled` and a notification has not already been sent.
    - Steps:
        1. Entry criteria: `Fulfillment_Status__c = 'Fulfilled'` AND the field just changed AND `Fulfillment_Notification_Sent__c` is `false`.
        2. Invoke the `Order.Order_Fulfilment_Notification` email alert.
        3. Update the record, setting `Fulfillment_Notification_Sent__c = true` to prevent re-sending on subsequent saves.

## Metadata Added

```
force-app/main/default/objects/Order/fields/Fulfillment_Status__c.field-meta.xml
force-app/main/default/objects/Order/fields/Fulfillment_Notification_Sent__c.field-meta.xml
force-app/main/default/email/OrderNotifications.emailFolder-meta.xml
force-app/main/default/email/OrderNotifications/Order_Fulfilment_Notification.email
force-app/main/default/email/OrderNotifications/Order_Fulfilment_Notification.email-meta.xml
force-app/main/default/workflows/Order.workflow-meta.xml
force-app/main/default/flows/Order_Fulfilment_Notification.flow-meta.xml
```

## Future Enhancements

- Replace the hard-coded recipient email addresses in the `Order_Fulfilment_Notification` alert with a Public Group or Queue so membership can be managed declaratively.
- Add a Flow unit test / regression check once Apex-based Flow testing is set up in this repo.
- Consider surfacing `Fulfillment_Status__c` on the Order page layout and list views so fulfilment progress is visible without opening the record detail.
