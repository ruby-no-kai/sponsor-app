# sponsor-expense-report

## Summary
<!-- 1-2 paragraph explanation -->

Allow custom sponsors to report their expenses for their custom sponsorship package. Organizers can then review the report, and make a decision on each expense line item.

## Motivation
<!-- This section should explain the motivation for the proposed change. Why is it needed? What problem does it solve? What usecases? This is the most important section. this can be lengthy. -->

We currently collect expense reports using Google Sheets, and it formats vary by sponsor, especially when sponsors can't share items externally. This makes it hard for us to track and review the expenses, and also makes it hard for sponsors to report their expenses in a consistent way. By providing a built-in expense reporting feature, we can streamline the process for both sponsors and organizers.

## Explanation
<!-- How we can use the proposed change when implemented? Irrustlate pseudo-code if this is an API change; include internal APIs such as models and concerns. -->
<!-- OTOH, this section should be a quick reference for consumers of the change, make it sound like a API document and get-started guide. Changes invisible to consumers, such as internal data models, must be explained in the 'Implementation Plan' section instead. -->

Scenarios:

- Sponsor can create an expense report.
- Sponsor can draft expense line items to illustrate the usage and the budget during the sponsorship period.
- Sponsor can submit the expense report for review.
- Sponsor can upload files for each line items.
- Sponsor can upload files to a specific line item.
- Sponsor can upload files in bulk, by dropping multiple files to the expense report page.
- Sponsor can upload image (jpeg,png,webp) and PDF files.
- Sponsor can list files, and can understand which files are not attached to any line items.
  - List pane includes list of unused files.
- Sponsor can reuse a same files across multiple line items, if needed.
- Sponsor can change order of line items by drag and drop.
- Each line items require amount and tax_amount. The tax amount is calculated automatically based on the tax rate configured in the system, but sponsors can override it if needed.
- Organizer can review the expense report, and make a decision on each line item (approve/reject).
- Organizer can leave a comment on a expense report when reviewing it, to provide feedback to the sponsor.
- Organizer has access to the same edit view as sponsors, to allow minor changes to correct the report if needed.
- Sponsor and Organizer can see the total of amount (without tax). Store it to ExpenseReport.
- Sponsor cannot edit approved expense report.
- Organizer can see the list of reports across sponsors from admin page. Table should have total amount without tax, and amount subtracted the report total from the sponsorship fee.
- System sends Slack notification to organizer feed channel on report submission.

Misc:

- Report editor and viewer is 3-columns (3-panes) view. Imagine the typical reimbursement report app.
  - Left pane is the list of line items, and center pane is the details of the selected line item, including the file attachments. Right pane is a preview of file.
- Report editor/viewer has 80vh height by default.

## Prior Art
<!-- if any. we can refer to external projects if needed.-->

## Security and Privacy Considerations
<!-- if any. -->

## Mission Scope

### Out of scope

- Admin only view does not require i18n.

### Expected Outcomes

## Implementation Plan
<!-- Detailed explanation of actual data models, code changes that is not visible to consumers of the change. Consumer-facing guides should go into 'Explanation' section instead. -->

### Database Design

- a single `ExpenseReport` model, belongs to `Sponsorship`. Has `total_amount` (without tax), `total_tax_amount`, `status` (draft, submitted, approved, rejected), `review_comment`.
- multiple `ExpenseFile` (use `AssetFileUploadable`) belongs to `Sponsorship`
- multiple `ExpenseLineItem` belongs to `ExpenseReport`. Has `amount`, `description`, `preliminal` (bool, to indicate whether it's irrustlative of planned budget usage)
  - can reference `ExpenseFile`s as its receipt, via `ExpenseLineItemFile` join table (can reference multiple files)
- Add `plans.price`, `plans.price_booth` to store the base sponsorship fee and booth add-on, default to 0, not null. We currently have free-text `price_human` column, but this is not machine-readable for calulation.

### API Design

```ruby
resource :sponsorship do
  resources :expense_report, only: [:create, :update, :show] do
    resources :line_items, controller: 'expense_line_items', only: [:create, :update, :destroy]
  end
  resources :expense_files do
    member do
      post :initiate_update
    end
  end
end
```

- `expense_report#show` provides HTML view to render frontend React component. otherwise it's a JSON API endpoint.

### Frontend

- Use TypeScript + React and embed using Rails view template.
  - Requires i18n. Pass i18n string from Rails to React via `<meta>` tag, and read it via React Provider.
- <!-- investigate and complete to follow the existing pattern -->


### Configuration

- `config/initializers/expense_report.rb` to add Rails.configuration.x.expense_report.tax_rate to configure the tax rate. This will be inherited to ExpenseReport in case for future tax rate changes. Default to 10% (JCT).


## Current Status
