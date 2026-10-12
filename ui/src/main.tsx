import "./app.css";
import { Toasty } from "@cloudflare/kumo";
import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { RouterProvider } from "react-router/dom";
import { SWRConfig } from "swr";
import { swrConfig } from "./lib/rpc.ts";
import { toastManager } from "./lib/toast.ts";
import { router } from "./router.tsx";

const rootElement = document.getElementById("root");
if (rootElement === null) throw new Error("index.html has no #root");

createRoot(rootElement).render(
  <StrictMode>
    <SWRConfig value={swrConfig}>
      <Toasty toastManager={toastManager}>
        <RouterProvider router={router} />
      </Toasty>
    </SWRConfig>
  </StrictMode>,
);
