import { createBrowserRouter } from "react-router";
import { Root, RootFallback } from "./routes/Root.tsx";
import { NotFound, RootError, RouteError } from "./routes/RouteError.tsx";
import { paths } from "./routes/paths.ts";

// Two trees: the staff area under /admin, and the sponsor area for every other path. Each path
// here also needs its pattern in paths.ts, or the dev server sends page loads of it to Rails.
export const router = createBrowserRouter([
  {
    Component: Root,
    ErrorBoundary: RootError,
    HydrateFallback: RootFallback,
    children: [
      {
        path: paths.admin,
        lazy: { Component: async () => (await import("./routes/admin/AdminLayout.tsx")).default },
        children: [
          {
            // Inside the layout, so the sidebar stays when a page fails.
            ErrorBoundary: RouteError,
            children: [
              // Conferences
              {
                index: true,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceList.tsx")).default,
                },
              },
              {
                path: paths.conferences,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceList.tsx")).default,
                },
              },
              {
                path: paths.conferenceNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceEditor.tsx")).default,
                },
              },
              {
                path: paths.conference,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceOverview.tsx")).default,
                },
              },
              {
                path: paths.conferenceEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/ConferenceEditor.tsx")).default,
                },
              },
              {
                path: paths.attendeesKeeper,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/AttendeesKeeper.tsx")).default,
                },
              },
              {
                path: paths.sponsorshipTable,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/SponsorshipTable.tsx")).default,
                },
              },

              // Form descriptions
              {
                path: paths.formDescriptionNew,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/FormDescriptionEditor.tsx")).default,
                },
              },
              {
                path: paths.formDescription,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/FormDescriptionEditor.tsx")).default,
                },
              },
              {
                path: paths.formDescriptionEdit,
                lazy: {
                  Component: async () =>
                    (await import("./routes/admin/FormDescriptionEditor.tsx")).default,
                },
              },

              // Plans

              // Sponsorships

              // Organizations

              // Booth assignments

              // Sponsor events

              // Announcements

              // Broadcasts

              // Expense reports

              { path: "*", Component: NotFound },
            ],
          },
        ],
      },
      {
        lazy: {
          Component: async () => (await import("./routes/sponsor/SponsorLayout.tsx")).default,
        },
        children: [
          // Sponsor: Translations

          // Sponsor: Applications

          // Sponsor: Exhibitions and events

          // Sponsor: Broadcasts and passes

          // Sponsor: Expense reports

          { path: "*", Component: NotFound },
        ],
      },
    ],
  },
]);
