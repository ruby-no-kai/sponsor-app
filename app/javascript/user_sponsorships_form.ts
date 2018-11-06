document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.sponsorships_form_billing_contact').forEach((elem) => {
    const checkbox = elem.querySelector('.form-check input[type=checkbox]') as HTMLInputElement;
    const fieldset = elem.querySelector('fieldset') as HTMLFieldSetElement;

    const handleChange = (e?: Event) => {
      if (checkbox.checked) {
        fieldset.classList.remove('d-none');
        fieldset.disabled = false;
      } else {
        fieldset.classList.add('d-none');
        fieldset.disabled = true;
      }
    }
    checkbox.addEventListener('change', handleChange);
    checkbox.addEventListener('click', handleChange);
    handleChange();
  });
});
