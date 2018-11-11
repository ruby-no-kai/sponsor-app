document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.sponsorships_form').forEach((formElem) => {
    formElem.querySelectorAll('.sponsorships_form_billing_contact').forEach((elem) => {
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

    formElem.querySelectorAll('.sponsorships_form_plans').forEach((elem) => {
      const boothCheckbox = formElem.querySelector('.sponsorships_form_booth_request input[type=checkbox]') as HTMLInputElement;
      const uneligibleHelpTextElem = formElem.querySelector('.sponsorships_form_booth_request_uneligible') as Element;
      const customizationRequestField = document.querySelector('.sponsorships_form_customization_request') as HTMLTextAreaElement;
      const profileFieldHelpElem = document.querySelector('.sponsorships_form_profile_help') as Element;

      const handleChange = (e: HTMLInputElement | null) => {
          if (!e) return;
          if (e.dataset.booth == '1') {
            uneligibleHelpTextElem.classList.add('d-none');
            boothCheckbox.disabled = false;
          } else {
            uneligibleHelpTextElem.classList.remove('d-none');
            boothCheckbox.disabled = true;
          }

          const wordsLimitHelp =  e.dataset.wordsLimitHelp;
          if (wordsLimitHelp) {
            profileFieldHelpElem.innerHTML = wordsLimitHelp;
          } else {
            profileFieldHelpElem.innerHTML = '';
          }

          customizationRequestField.required = e.dataset['other'] == '1';
      };
      handleChange(elem.querySelector('input[type=radio]:checked') as HTMLInputElement);

      elem.querySelectorAll('input[type=radio]').forEach((planRadioElem) => {
        const planRadio = planRadioElem as HTMLInputElement;
        planRadio.addEventListener('change', (e) => {
          handleChange(e.target as HTMLInputElement);
        });
      }); 
    }); 
  });
});
