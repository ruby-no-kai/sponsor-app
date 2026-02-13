document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".sponsor_events_form").forEach((formElem) => {
    const ENGLISH_REGEX =
      /^(?:[\p{Script=Latin}\p{Script=Zyyy}\p{Sc}\p{Sk}\p{Sm}\p{So}])*$/u;

    formElem
      .querySelectorAll<HTMLInputElement>(
        'input[name="sponsor_event[title]"], input[name="sponsor_event[price]"], input[name="sponsor_event[capacity]"], input[name="sponsor_event[location_en]"]',
      )
      .forEach((inputElem) => {
        const onChange = () => {
          // Check all monitored fields
          const allFieldsEnglish = Array.from(
            formElem.querySelectorAll<HTMLInputElement>(
              'input[name="sponsor_event[title]"], input[name="sponsor_event[price]"], input[name="sponsor_event[capacity]"], input[name="sponsor_event[location_en]"]',
            ),
          ).every((field) => ENGLISH_REGEX.test(field.value));

          const warningElems = formElem.querySelectorAll<HTMLElement>(
            ".sponsor_events_form__warning",
          );

          warningElems.forEach((w) => {
            if (w.dataset.warningKind === "english") {
              if (!allFieldsEnglish) {
                w.classList.remove("d-none");
                w.querySelectorAll("input").forEach((i) => (i.required = true));
              } else {
                w.classList.add("d-none");
                w.querySelectorAll("input").forEach(
                  (i) => (i.required = false),
                );
              }
            }
          });
        };
        inputElem.addEventListener("input", onChange);
        inputElem.addEventListener("change", onChange);
      });
  });
});
