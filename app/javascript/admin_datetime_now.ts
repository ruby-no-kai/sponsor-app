function setNow(input: HTMLInputElement) {
  input.value = new Date().toISOString().slice(0, 19);
}

// Native Invoker Commands API (command event fires on the target element)
document.addEventListener("command", ((e: Event) => {
  const event = e as Event & { command: string };
  if (event.command !== "--set-now") return;

  const target = event.target;
  if (target instanceof HTMLInputElement && target.type === "datetime-local") {
    setNow(target);
  }
}) as EventListener);

// Fallback for browsers where commandfor/command attributes don't fire events yet
document.addEventListener("click", (e: MouseEvent) => {
  const button = (e.target as Element).closest<HTMLButtonElement>('button[command="--set-now"]');
  if (!button) return;

  const targetId = button.getAttribute("commandfor");
  if (!targetId) return;

  const input = document.getElementById(targetId);
  if (input instanceof HTMLInputElement && input.type === "datetime-local") {
    setNow(input);
  }
});
