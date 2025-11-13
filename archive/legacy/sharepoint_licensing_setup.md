# SharePoint Licensing System Setup (FREE Cloud Solution)

## Overview
This system uses Power Automate + SharePoint to automatically process Stripe payments and generate licenses without any API keys or paid services.

## SharePoint List Setup

### Create SharePoint List: "Licenses"
1. Go to your SharePoint site
2. Create new list: **Licenses**
3. Add these columns:

| Column Name | Type | Required | Notes |
|-------------|------|----------|-------|
| InternetMessageId | Single Line of Text | Yes | Unique email ID for deduplication |
| CustomerEmail | Single Line of Text | Yes | Customer's email address |
| Product | Single Line of Text | Yes | Product name (Basic/Pro/Enterprise/Lifetime) |
| Amount | Number | Yes | Purchase amount |
| Currency | Choice | Yes | USD, EUR, GBP (default USD) |
| LicenseKey | Single Line of Text | Yes | Generated license key |
| Status | Choice | Yes | issued, duplicate, error |
| IssuedAt | Date and Time | Yes | When license was created |
| Notes | Multiple Lines of Text | No | For debugging issues |

## Power Automate Flow Setup

### Flow Name: "Stripe License Generator"

### Step 1: Trigger - When a new email arrives
```
Trigger: When a new email arrives (V3)
- Folder: Inbox
- From: Contains "@stripe.com"
- Subject: Contains "Receipt" OR "Payment"
- Include Attachments: No
- Importance: Any
```

### Step 2: Get full email details
```
Action: Get email (V3)
- Message Id: Message Id (from trigger)
- Output: Body, Internet Message Id
```

### Step 3: Initialize variables
```
Action: Initialize variable
- Name: bodyHtml
- Type: String
- Value: Body (from Get email)
```

### Step 4: Deduplication check
```
Action: Get items (SharePoint)
- Site Address: [Your SharePoint site URL]
- List Name: Licenses
- Filter Query: InternetMessageId eq '[InternetMessageId from Get email]'
- Top Count: 1

Action: Condition
- If: length(body('Get_items')?['value']) is greater than 0
- Then: Terminate (Status: Succeeded, Message: "Duplicate email - license already issued")
```

### Step 5: Parse email content
```
Action: Compose
- Name: plainText
- Inputs: replace(replace(replace(variables('bodyHtml'), '<br>', '\n'), '&nbsp;', ' '), '&amp;', '&')

Action: Compose
- Name: amountLine
- Inputs: first(filter(split(outputs('plainText'), '\n'), contains(item(), '$')))

Action: Compose
- Name: amount
- Inputs: float(replace(first(split(last(split(outputs('amountLine'), '$')), ' ')), ',', ''))

Action: Compose
- Name: currency
- Inputs: if(contains(outputs('amountLine'), 'USD'), 'USD', 'USD')  // Default to USD

Action: Compose
- Name: emailLine
- Inputs: first(filter(split(outputs('plainText'), '\n'), and(contains(item(), '@'), contains(item(), '.'))))

Action: Compose
- Name: customerEmail
- Inputs: trim(last(split(replace(outputs('emailLine'), ':', ' '), ' ')))

Action: Compose
- Name: productLine
- Inputs: first(filter(split(outputs('plainText'), '\n'), or(contains(item(), 'Description'), contains(item(), 'Product'))))

Action: Compose
- Name: product
- Inputs: trim(last(split(outputs('productLine'), ':')))
```

### Step 6: Generate license key
```
Action: Compose
- Name: licenseKey
- Inputs: toUpper(concat(substring(replace(guid(), '-', ''), 0, 5), '-', substring(replace(guid(), '-', ''), 5, 5), '-', substring(replace(guid(), '-', ''), 10, 5), '-', substring(replace(guid(), '-', ''), 15, 5), '-', substring(replace(guid(), '-', ''), 20, 5)))
```

### Step 7: Store in SharePoint
```
Action: Create new item (SharePoint)
- Site Address: [Your SharePoint site URL]
- List Name: Licenses
- Title: [Leave empty - SharePoint auto-generates]
- InternetMessageId: InternetMessageId (from Get email)
- CustomerEmail: outputs('customerEmail')
- Product: outputs('product')
- Amount: outputs('amount')
- Currency: outputs('currency')
- LicenseKey: outputs('licenseKey')
- Status: issued
- IssuedAt: utcNow()
```

### Step 8: Send license email
```
Action: Send an email (V2)
- To: outputs('customerEmail')
- Subject: Your RescuePC License Key
- Body:
<html>
<body>
<h2>Welcome to RescuePC!</h2>
<p>Thank you for your purchase. Here are your license details:</p>

<p><strong>License Key:</strong> @{outputs('licenseKey')}</p>
<p><strong>Product:</strong> @{outputs('product')}</p>
<p><strong>Amount:</strong> @{outputs('amount')} @{outputs('currency')}</p>

<p><strong>Download:</strong> <a href="https://yourdomain.com/download">RescuePC Repairs</a></p>

<h3>How to Activate:</h3>
<ol>
<li>Download and install RescuePC Repairs</li>
<li>Launch the application</li>
<li>Enter your license key when prompted</li>
<li>Use the email address associated with this purchase</li>
</ol>

<p>If you have any questions, contact support@rescuepcrepairs.com</p>

<p>Best regards,<br>RescuePC Team</p>
</body>
</html>
```

### Step 9: Clean up email
```
Action: Mark as read (Outlook)
- Message Id: Message Id (from trigger)

Action: Move email (Outlook)
- Message Id: Message Id (from trigger)
- Folder: Processed/Stripe (create this folder first)
```

## Testing the Flow

1. **Test Purchase**: Make a test purchase on your Stripe account
2. **Check Email**: Verify the Stripe receipt email arrives in your Outlook
3. **Monitor Flow**: Check Power Automate run history for any errors
4. **Verify SharePoint**: Confirm license was created in the list
5. **Check Customer Email**: Verify customer received the license email

## Customization Notes

- **Email Parsing**: After first real purchase, check the `plainText` output in run history and adjust the parsing logic if needed
- **Product Mapping**: You may need to map Stripe product names to your internal product names
- **Error Handling**: Add error handling for parsing failures
- **Notifications**: Optionally add Teams notifications for new sales

## Integration with PowerShell App

The PowerShell application will query SharePoint directly or use a simple API endpoint to validate licenses. For the free solution, you can:

1. Use SharePoint REST API (requires authentication)
2. Export licenses to a public JSON file periodically
3. Use Power Automate to generate API endpoints

This system processes licenses automatically 24/7 without any servers or paid services!
