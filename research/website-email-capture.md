# Email Capture for budgetvault.io

## Option 1: Buttondown (Free, privacy-friendly, no tracking)
Best fit for BudgetVault's privacy brand. Free up to 100 subscribers.

### Setup
1. Go to buttondown.com and create a free account
2. Your subscribe URL will be: `https://buttondown.com/api/emails/embed-subscribe/budgetvault`

### Embed Code (paste into Base44 HTML block)
```html
<div style="max-width: 440px; margin: 2rem auto; text-align: center;">
  <h3 style="font-size: 1.25rem; font-weight: 600; margin-bottom: 0.5rem;">
    Get notified when we launch
  </h3>
  <p style="color: #666; font-size: 0.9rem; margin-bottom: 1rem;">
    No spam. One email on launch day. That's it.
  </p>
  <form
    action="https://buttondown.com/api/emails/embed-subscribe/budgetvault"
    method="post"
    target="popupwindow"
    style="display: flex; gap: 0.5rem;"
  >
    <input
      type="email"
      name="email"
      placeholder="your@email.com"
      required
      style="flex: 1; padding: 0.75rem 1rem; border: 1px solid #ddd; border-radius: 12px; font-size: 1rem;"
    />
    <button
      type="submit"
      style="padding: 0.75rem 1.5rem; background: #2563EB; color: white; border: none; border-radius: 12px; font-size: 1rem; font-weight: 600; cursor: pointer;"
    >
      Notify Me
    </button>
  </form>
  <p style="color: #999; font-size: 0.75rem; margin-top: 0.5rem;">
    We don't track opens or clicks. Because of course we don't.
  </p>
</div>
```

## Option 2: Mailchimp (Free up to 500 subscribers)
More features but adds tracking pixels by default.

### Setup
1. Go to mailchimp.com, create free account
2. Create an Audience called "BudgetVault Launch"
3. Go to Signup Forms > Embedded Forms
4. Copy the form action URL and replace in the code above

## Option 3: Simple Google Form (Zero infrastructure)
If you want the absolute simplest approach:
1. Create a Google Form with one field: "Email"
2. Link it from the website as "Get notified"
3. Export to Sheets when ready to send

---

## Recommended: Buttondown
- Privacy-friendly (aligns with brand)
- Free tier is generous
- Simple API, easy embed
- No tracking pixels by default
- Can send the launch email + price increase email from there

## Email Sequence Plan
1. **Launch day:** "BudgetVault is live on the App Store" + App Store link
2. **Day 7:** "First week update" + early user feedback highlights
3. **Day 25:** "Price goes from $14.99 to $24.99 in 5 days" (urgency)
4. **Day 30:** "Last chance: $14.99 pricing ends today"
