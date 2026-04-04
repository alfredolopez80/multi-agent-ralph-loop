# Accessibility Checklist (WCAG 2.1 AA)

## Perceivable
- [ ] All images have meaningful alt text (or alt="" for decorative)
- [ ] Color is not the only means of conveying information
- [ ] Text contrast ratio >= 4.5:1 (normal), >= 3:1 (large)
- [ ] Content is readable at 200% zoom
- [ ] Video has captions, audio has transcripts

## Operable
- [ ] All functionality available via keyboard
- [ ] Focus order is logical (follows visual flow)
- [ ] Focus indicator is visible (never `outline: none` without replacement)
- [ ] No keyboard traps (can Tab in AND out of components)
- [ ] Skip navigation link for repetitive content
- [ ] No content that flashes > 3 times/second
- [ ] Touch targets >= 44x44px on mobile

## Understandable
- [ ] Language attribute set on `<html>`
- [ ] Form labels associated with inputs (`<label for="">`)
- [ ] Error messages identify the field and suggest correction
- [ ] Consistent navigation across pages
- [ ] Instructions don't rely solely on sensory (color, shape, position)

## Robust
- [ ] Valid HTML (no duplicate IDs)
- [ ] ARIA roles used correctly (not overriding native semantics)
- [ ] Status messages use `role="status"` or `aria-live`
- [ ] Components work with assistive technology

## By Component Type

### Buttons
- [ ] `<button>` element (not styled `<div>`)
- [ ] Accessible name (text content or `aria-label`)
- [ ] Disabled state uses `disabled` attribute + visual indicator

### Forms
- [ ] Every input has a visible `<label>`
- [ ] Required fields marked with `aria-required="true"`
- [ ] Error messages linked with `aria-describedby`
- [ ] Form groups use `<fieldset>` + `<legend>`

### Modals/Dialogs
- [ ] Focus trapped inside when open
- [ ] Close on Escape key
- [ ] Focus returns to trigger on close
- [ ] `role="dialog"` + `aria-modal="true"`
- [ ] Has accessible name (`aria-labelledby`)

### Navigation
- [ ] `<nav>` element with `aria-label`
- [ ] Current page indicated (`aria-current="page"`)
- [ ] Dropdown menus keyboard accessible
