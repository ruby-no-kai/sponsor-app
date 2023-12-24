document.addEventListener("DOMContentLoaded", () => {
  document.querySelectorAll(".booth_assignment_form").forEach((topElem) => {
    const checkBoxes = topElem.querySelectorAll(
      "input[type=checkbox]",
    ) as NodeListOf<HTMLInputElement>;
    topElem
      .querySelectorAll("button.booth_assignment_select_all_button")
      .forEach((button) => {
        button.addEventListener("click", (e) => {
          e.preventDefault();
          checkBoxes.forEach((checkbox) => (checkbox.checked = true));
        });
      });
    topElem
      .querySelectorAll("button.booth_assignment_select_none_button")
      .forEach((button) => {
        button.addEventListener("click", (e) => {
          e.preventDefault();
          checkBoxes.forEach((checkbox) => (checkbox.checked = false));
        });
      });
  });
});
