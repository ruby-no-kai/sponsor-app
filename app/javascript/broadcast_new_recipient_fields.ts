document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.broadcast_new_recipient_fields').forEach((formElem) => {
    formElem.querySelectorAll('.broadcast_new_recipient_fields_selector').forEach((elem) => {
      const select = elem as HTMLSelectElement;

      const handleChange = (e?: Event) => {
        const fieldsets = formElem.querySelectorAll(`fieldset`);
        const fieldset = formElem.querySelector(`.broadcast_new_recipient_fields_kind__${select.value}`) as HTMLFieldSetElement;
        if (fieldset) {
          fieldsets.forEach((fs) => {
            fs.classList.add('d-none');
            fs.disabled = true;
          });
          fieldset.classList.remove('d-none');
          fieldset.disabled = false;
        }
      }
      select.addEventListener('change', handleChange);
      handleChange();
    });
  });
});
