document.addEventListener("DOMContentLoaded", () => {
  console.log("DOMContentLoaded");
  document.querySelectorAll(".sponsorships_form").forEach((formElem) => {
    formElem
      .querySelectorAll("select.sponsorship_id_to_copy_selector")
      .forEach((elem_) => {
        const elem = elem_ as HTMLSelectElement;
        elem.addEventListener("change", () => {
          const query = new URLSearchParams(location.search);
          query.set("sponsorship_id_to_copy", elem.value);
          location.search = query.toString();
        });
      });

    formElem
      .querySelectorAll(".sponsorships_form_billing_contact")
      .forEach((elem) => {
        const checkbox = elem.querySelector(
          ".form-check input[type=checkbox]"
        ) as HTMLInputElement;
        const fieldset = elem.querySelector("fieldset") as HTMLFieldSetElement;

        const handleChange = (e?: Event) => {
          if (checkbox.checked) {
            fieldset.classList.remove("d-none");
            fieldset.disabled = false;
          } else {
            fieldset.classList.add("d-none");
            fieldset.disabled = true;
          }
        };
        checkbox.addEventListener("change", handleChange);
        checkbox.addEventListener("click", handleChange);
        handleChange();
      });

    const calculateTotalAttendees = () => {
      const totalElem = formElem.querySelector(
        ".sponsorships_form_tickets__total"
      ) as Element;
      if (!totalElem) return;

      const selectedPlanElem = formElem.querySelector(
        ".sponsorships_form_plans input[type=radio]:checked"
      ) as HTMLInputElement;
      const ticketsIncludedInPlanElem = formElem.querySelector(
        ".sponsorships_form_tickets__included_in_plan"
      )! as Element;
      const additionalAttendeesElem = formElem.querySelector(
        ".sponsorships_form_tickets__additional_attendees input"
      )! as HTMLInputElement;

      const numberOfGuests = selectedPlanElem
        ? parseInt(selectedPlanElem.dataset["guests"]!, 10)
        : 0;
      const additionalAttendees = additionalAttendeesElem.valueAsNumber;

      const total =
        numberOfGuests + (isNaN(additionalAttendees) ? 0 : additionalAttendees);

      ticketsIncludedInPlanElem.innerHTML = `${numberOfGuests}`;
      totalElem.innerHTML = `${total}`;
    };
    formElem
      .querySelectorAll(
        ".sponsorships_form_tickets__additional_attendees input"
      )
      .forEach((elem) => {
        elem.addEventListener("change", () => calculateTotalAttendees());
        elem.addEventListener("click", () => calculateTotalAttendees());
      });
    calculateTotalAttendees();

    formElem.querySelectorAll(".sponsorships_form_plans").forEach((elem) => {
      const boothCheckbox = formElem.querySelector(
        ".sponsorships_form_booth_request input[type=checkbox]"
      ) as HTMLInputElement;
      const uneligibleHelpTextElem = formElem.querySelector(
        ".sponsorships_form_booth_request_uneligible"
      ) as Element;
      const customizationRequestField = document.querySelector(
        ".sponsorships_form_customization_request"
      ) as HTMLTextAreaElement;
      const profileFieldHelpElem = document.querySelector(
        ".sponsorships_form_profile_help"
      ) as Element;
      const acceptanceHelpElem = document.querySelector(
        ".sponsorships_acceptance_help"
      ) as Element;

      const handleChange = (e: HTMLInputElement | null) => {
        if (!e) return;
        if (e.dataset.booth == "1") {
          uneligibleHelpTextElem.classList.add("d-none");
          boothCheckbox.disabled = false;
        } else {
          uneligibleHelpTextElem.classList.remove("d-none");
          boothCheckbox.disabled = true;
        }

        const wordsLimitHelp = e.dataset.wordsLimitHelp;
        if (wordsLimitHelp) {
          profileFieldHelpElem.innerHTML = wordsLimitHelp;
        } else {
          profileFieldHelpElem.innerHTML = "";
        }

        const acceptanceHelp = e.dataset.acceptanceHelp;
        if (acceptanceHelp) {
          acceptanceHelpElem.innerHTML = acceptanceHelp;
        } else {
          acceptanceHelpElem.innerHTML = "";
        }

        customizationRequestField.required = e.dataset["other"] == "1";
      };
      handleChange(
        elem.querySelector("input[type=radio]:checked") as HTMLInputElement
      );

      elem.querySelectorAll("input[type=radio]").forEach((planRadioElem) => {
        const planRadio = planRadioElem as HTMLInputElement;
        planRadio.addEventListener("change", (e) => {
          calculateTotalAttendees();
          handleChange(e.target as HTMLInputElement);
        });
      });
    });
  });
});
